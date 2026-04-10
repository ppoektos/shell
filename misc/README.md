# Misc

Standalone automation scripts that don't belong to a larger system.

## Files

| File | Description |
|------|-------------|
| `redmine-pm-schedule.sh` | Reads PM reporting schedules from Redmine custom fields and auto-provisions per-project cron jobs that POST recurring PM tasks via the Redmine REST API |

## How it works

### `redmine-pm-schedule.sh`

Reads two Redmine custom fields per project: one holding the assigned user ID and one holding the schedule (`weekly`, `fortnightly`, `monthly`). For each project with a schedule set it generates a Redmine issue XML file and writes a `/etc/cron.d/projNNN` file containing the appropriate cron expression and a `curl` POST to the Redmine issues API. If the schedule field is later cleared, the script removes both the cron file and the XML — the DB is the source of truth for which cron jobs should exist. The script is idempotent for existing entries: it checks for the cron file before creating it, so re-running does not duplicate jobs.

## Notable patterns

**Self-cleaning cron jobs via DB query.** The script doesn't maintain a separate list of which cron files it created — it re-derives that from the DB on every run. Projects with a blank schedule field cause their cron file to be deleted. The database is the authoritative registry; the filesystem just reflects it.

**`/etc/cron.d` as a programmable scheduler.** Rather than editing a single crontab, the script writes one file per project into `/etc/cron.d/`. Each file contains exactly one cron line. Adding or removing a schedule is atomic — drop or delete one file — and the set of active schedules is directly inspectable as a directory listing.

**Fortnightly via modulo week number.** The fortnightly cron expression runs every Monday but guards with `test $(( $(date +%W) % 2 )) -eq 1` — if the ISO week number is odd the curl fires, otherwise not. No external tool, no state file — the calendar week number itself is the alternating flag.
