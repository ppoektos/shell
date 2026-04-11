# Misc

Standalone automation scripts that don't belong to a larger system.

## Files

| File | Description |
|------|-------------|
| `redmine-pm-schedule.sh` | Reads PM reporting schedules from Redmine custom fields and auto-provisions per-project cron jobs that POST recurring PM tasks via the Redmine REST API |
| `nut-upssched-cmd.sh` | NUT `upssched` event handler — sends email and wall alerts on power events, initiates an orderly shutdown after a configurable grace period or immediately on battery critical |
| `ups-powerout.sh` | OpenBSD power-out handler — reads remaining battery runtime from the kernel sensor subsystem and shuts down if it falls below a threshold |
| `wireguard-manage.sh` | Interactive CLI for managing WireGuard VPN servers and clients — creates/removes servers and peers, generates QR codes, supports apt/dnf/slackpkg and both systemd and rc.local startup |
| `rmtoo-jenkins.sh` | Jenkins build script for rmtoo requirements processing — determines which `.req` files changed in the triggering SVN revision, runs `make`, and exports PDF/PNG artifacts; writes a properties file so a downstream job can email the output to the committing engineer |

## How it works

### `redmine-pm-schedule.sh`

Reads two Redmine custom fields per project: one holding the assigned user ID and one holding the schedule (`weekly`, `fortnightly`, `monthly`). For each project with a schedule set it generates a Redmine issue XML file and writes a `/etc/cron.d/projNNN` file containing the appropriate cron expression and a `curl` POST to the Redmine issues API. If the schedule field is later cleared, the script removes both the cron file and the XML — the DB is the source of truth for which cron jobs should exist. The script is idempotent for existing entries: it checks for the cron file before creating it, so re-running does not duplicate jobs.

### `nut-upssched-cmd.sh`

NUT (Network UPS Tools) calls `upssched` on UPS events; `upssched` in turn fires timers and calls this script with an event name as the first argument. Each event branch sends an email notification and a `wall` broadcast to all logged-in users. The two shutdown-triggering events (`shutdownnow` and `shutdowncritical`) additionally call `/sbin/shutdown -h +0`.

The same script was deployed across all NUT-monitored servers, with the grace period before `shutdownnow` fires set per-host in `upssched.conf`:
- Main office infrastructure servers: 6 hours
- Edge server: 2 hours
- Remote office server: 60 minutes

### `ups-powerout.sh`

OpenBSD-specific handler for hosts where the UPS presents as a kernel sensor device (`upd0`). Rather than relying on NUT, it reads the remaining battery runtime directly from the OpenBSD sensor subsystem via `sysctl hw.sensors.upd0.timedelta0`. The value is returned as a floating-point seconds string; two rounds of shell parameter expansion strip the key prefix and the decimal fraction before dividing by 60 to get minutes. If the result is at or below the threshold (20 minutes), the script initiates a shutdown.

### `wireguard-manage.sh`

Interactive CLI for the full lifecycle of WireGuard VPN servers and clients on a Linux host. On first run it detects whether a server config already exists under `/etc/wireguard/wgmy*.conf`; if multiple exist it presents a numbered menu. New server setup walks through subnet selection, port selection, and external IP selection — each step scanning existing configs and live network state to offer a conflict-free default. Server metadata (EIP, subnet, port) is embedded as structured comments in the config file so it can be re-read without a separate state file.

Client management handles add, list, remove, and QR regeneration. Each new client gets its own keypair (generated in a `mktemp` directory, deleted after use), a sequential VPN IP, and a choice of routing mode: full tunnel (`0.0.0.0/0`), VPN-only (`subnet/24`), or custom CIDR list with inline validation. The resulting client config is printed as a QR code via `qrencode -t UTF8` for mobile import.

Startup is handled via `systemctl enable --now wg-quick@iface` on systemd hosts, or by appending to `/etc/rc.d/rc.local` on Slackware. All output is logged to `/tmp/wireguard-manage.log` via `main 2>&1 | tee`.

### `rmtoo-jenkins.sh`

Jenkins build script triggered by SVN commits to the rmtoo requirements repository. It reads the current SVN revision from `svn info`, then SSHes to the SCM host and runs `svnlook changed` to get the list of files modified in that revision. Only files under an `input/` path are processed — these are the raw `.req` requirement files. The first directory component of each path is taken as the contributing engineer's username.

Changed files are copied into the rmtoo build directory, then `source ./setenv.sh DEB && make` compiles them into PDF and PNG artifacts. Outputs are copied back to the workspace under the user's personal output directory. Finally, `rcpt=${user}@<DOMAIN>` is written to `rmtoo.properties` so a downstream Jenkins job can send the engineer their compiled requirements document.

## Notable patterns

**Self-cleaning cron jobs via DB query.** `redmine-pm-schedule.sh` doesn't maintain a separate list of which cron files it created — it re-derives that from the DB on every run. Projects with a blank schedule field cause their cron file to be deleted. The database is the authoritative registry; the filesystem just reflects it.

**`/etc/cron.d` as a programmable scheduler.** Rather than editing a single crontab, the script writes one file per project into `/etc/cron.d/`. Each file contains exactly one cron line. Adding or removing a schedule is atomic — drop or delete one file — and the set of active schedules is directly inspectable as a directory listing.

**Fortnightly via modulo week number.** The fortnightly cron expression runs every Monday but guards with `test $(( $(date +%W) % 2 )) -eq 1` — if the ISO week number is odd the curl fires, otherwise not. No external tool, no state file — the calendar week number itself is the alternating flag.

**Two-event shutdown ladder.** `nut-upssched-cmd.sh` handles two distinct shutdown triggers: `shutdownnow` (grace period expired — orderly) and `shutdowncritical` (battery level critical — emergency). The grace period is defined in `upssched.conf`, not in this script, so the same handler works across hosts with different battery capacities simply by adjusting the timer.

**Reading hardware sensors via `sysctl`.** `ups-powerout.sh` bypasses NUT entirely and reads `hw.sensors.upd0.timedelta0` directly from the OpenBSD kernel. The value `NNN.NNN secs` is parsed with two shell parameter expansions — `${var#*=}` strips the key, `${var%.*}` drops the decimal — before integer arithmetic converts seconds to minutes. No external tools, no parsing utilities.

**Config file as its own metadata store.** `wireguard-manage.sh` embeds the server's external IP, port, and subnet as structured comment lines (`# EIP:`, `# SUB:`) inside the WireGuard config file itself. On re-entry the script reads these back with `awk -F: '/^# EIP/'` — no separate state file, no database. The config is self-describing.

**Conflict-aware suggestions for subnet and port.** Before prompting, the script scans all existing WireGuard configs for used subnets and runs `ss -tulwnH` to collect used ports. It presents the reserved list to the user and pre-fills the prompt (`read -e -i "default"`) with the next free value. The user can accept or override.

**`umask 177` before key generation.** Private keys are written with `umask 177` in effect, ensuring they are created `rw-------` regardless of the system default. The umask is set immediately before the `wg genkey | tee` pipeline so no other files are affected.

**Peer blocks delimited by sentinel comments.** Each client in the server config is wrapped in `# BEGIN PEER:name` / `# END PEER:name` markers. Deletion is a single `sed -i` range delete: `"/^# BEGIN.*name$/,/^# END.*name$/d"` — no line number arithmetic, no temp files.

**Username extracted from SVN path.** In `rmtoo-jenkins.sh` the committing engineer's identity is derived from the repository path structure — the first directory component of each changed file (`awk -F/ '{print $1}'`) is the username. This drives both the output destination (`$wd/$user/output/`) and the notification email (`${user}@<DOMAIN>`), with no explicit username mapping.

**Jenkins properties file for downstream notification.** Rather than sending the email directly, the script writes `rcpt=user@domain` to `rmtoo.properties`. Jenkins picks this up as a build parameter for the next job in the pipeline — keeping email delivery outside the build script and making the recipient configurable without changing code.
