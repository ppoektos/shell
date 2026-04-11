# Shell Scripts

A collection of shell automation scripts built organically over several years to support day-to-day IT operations and business processes at a small engineering company. Scripts were written to solve real problems as they appeared — not from a software engineering background, but from a sysadmin-and-necessity one. Most predate modern tooling, container ecosystems, and AI assistants.

The common stack: **bash**, **MySQL**, **PHP web UIs**, **TWiki for data entry**, **mutt/sendmail for email**, and later **Telegram for notifications**. No frameworks, no dependencies beyond what was already on the servers.

---

## Projects

| Directory | What it does |
|-----------|-------------|
| [backup](backup/) | MySQL, Confluence, and NAS backup scripts with rotating archives distributed to three hosts via SCP |
| [confluence](confluence/) | Confluence automation — project space creation, weekly IPR report generation, productivity charts, QA document index, and FlexLM license server restarts |
| [effort](effort/) | Developer productivity and efficiency tracking — computes invoiceable/non-invoiceable hours, productivity, efficiency, and PE metrics from Redmine; stores monthly results in MySQL; delivers reports via email |
| [expenses](expenses/) | Office cash and expense tracking for two offices — employees enter records into a TWiki table; a daily cron job parses the file, loads records into MySQL, and recalculates running balances |
| [honeywell](honeywell/) | Pulls access events from a Honeywell security panel into MySQL and provides a PHP web UI with arrival-band reporting |
| [iot](iot/) | ThingsBoard and Azure IoT Hub scripts — device and user registration, GPS telemetry simulation, historical data replay, and UPS monitoring via NUT |
| [isp-failover](isp-failover/) | Dual-WAN failover daemon for OpenBSD gateways — monitors connectivity, switches ISPs, reloads PF and IPSec, with a PHP web UI for manual control |
| [lunch-order](lunch-order/) | Automated daily lunch ordering — reads employee choices from a TWiki table, places orders by email, enforces a 3-person supplier minimum, tracks in MySQL, resets the form after each run |
| [misc](misc/) | Standalone scripts: WireGuard VPN manager, NUT UPS shutdown handler, OpenBSD power-out handler, Redmine PM cron provisioner, rmtoo Jenkins build script |
| [svn](svn/) | SVN hook suite — pre-commit message validation, post-commit email and MySQL logging, keyword- and path-triggered Jenkins builds, hook mass-deployment, and daily commit reports |

---

## What this replaces

These ten projects cover backup, time tracking, expense management, physical access control, IoT telemetry, network failover, catering logistics, VPN management, and development workflow tooling — areas where commercial products exist but either charge per-seat fees that add up fast for a small company, or don't expose the custom business logic the scripts implement.

Off-the-shelf tools in these categories (Veeam, Tempo Timesheets, Expensify, Envoy, Azure IoT Central, SD-WAN services, Tailscale, GitLab CI) would run roughly **$15,000–60,000 per year** in combined licensing for a 50-person operation. That still wouldn't cover the custom parts: the PE productivity metric and country-specific working-hour norms in `effort`, the multi-company billing split in `lunch-order`, the arrival-band access report in `honeywell`, or the coordinated dual-endpoint IPSec reload in `isp-failover`. Those would require bespoke development on top.

Commissioning a contractor to build equivalent custom tools from scratch — proper web apps, scheduled services, API integrations — would represent roughly **40–70 developer-weeks** of work, or around **$80,000–140,000** at mid-2010s European contractor rates. With annual maintenance, that compounds quickly.

What actually happened: a sysadmin with no formal development background built working solutions iteratively over several years, at operational rather than project cost. The scripts ran without significant overhaul for the life of the infrastructure they served.

---

## Non-trivial technical achievements

Several solutions in this collection are more sophisticated than their line count suggests.

### Effort tracking with HR boundary logic

The `effort` project implements what is effectively a payroll-adjacent calculation engine. Nominal working hours are not a simple `days × hours` formula — they account for:

- Users who joined or left mid-month (start/finish day pro-rating via `ncal`)
- Different working norms per country: Ukrainian employees work 8 h/day; Danish employees 7.4 h/day (37-hour week); one DK employee is on a 28.5 h/week (5.7 h/day) contract, handled as a named case
- Public holidays that fall *before* a user's start date must not reduce their nominal hours — the holiday is only counted if it falls within the user's active period for that month

Commercial time-tracking tools (Tempo, Harvest) don't expose this level of contract-aware nominal hour calculation. Building it correctly in a "proper" application would require a proper HR data model, contract table, and calendar integration.

### QA document index as a real-time event pipeline

The `confluence/qa-index` system spans three machines and two event types. On the QNAP NAS, `incron` watches every directory under the QA share for filesystem events. When a file matching `*_released*` is created or deleted, it SSHes to the Confluence server and triggers a full index rebuild. When a new directory is created, the watch list extends itself — no manual re-registration ever needed.

The pipeline is: NAS filesystem change → inotify → incron → SSH → Confluence REST API. Building an equivalent with a proper stack today would mean: a file-event service (FSEvents/inotify daemon), a message queue, a worker process, and a Confluence webhook integration. The shell implementation does all of this in two scripts and an incron config file.

### ISP failover with coordinated remote state

The `isp-failover` daemon does more than swap a default route. When the primary ISP fails, it must reload the PF firewall with a different rule set *and* reload the IPSec tunnel configuration on the *remote* endpoint via SSH — because the tunnel's local-side IP has just changed. Coordinating state across two machines over an unreliable network link is a real distributed systems problem. Commercial dual-WAN routers handle local failover; they don't reach out to the other end of a VPN and reconfigure it.

### Azure IoT Hub authentication without an SDK

Azure Device Provisioning Service requires a Shared Access Signature: an HMAC-SHA256 token computed from the master key, the scope ID, and an expiry timestamp — a two-step flow (register → poll for assigned hub) before any telemetry can be sent. `VoltageToAzure.sh` implements this entirely in bash using an inline Node.js one-liner for the HMAC computation. No Azure SDK, no Python, no configuration file — the full auth protocol runs as a shell function. Getting this right requires reading the SAS specification and understanding the key derivation correctly, not just calling an SDK method.

### Honeywell integration without an official API

There is no public API for the Honeywell panel model used. `honeywell.sh` reverse-engineered the web interface: it authenticates via a form POST, extracts the session cookie from response headers using shell parameter expansion alone (`${cookie##*:}` / `${cookie%%;*}`), then downloads the event CSV from the panel's internal upload endpoint. Any firmware update that changes the login form or cookie format silently breaks the integration — a risk that comes with reverse-engineered integrations. A "proper" integration would require vendor API access or a supported SDK, neither of which existed for this hardware.

### WireGuard manager as a complete cross-platform CLI tool

`wireguard-manage.sh` in `misc` handles the full lifecycle of WireGuard servers and clients across Linux distributions (apt, dnf, slackpkg) and init systems (systemd, rc.local). Non-trivial features include:

- **Conflict-aware setup**: scans existing configs and live network state (`ss -tulwnH`) before suggesting a subnet or port, pre-filling the prompt with the next free value
- **Config as its own metadata store**: external IP, subnet, and port are embedded as structured comments inside the WireGuard config so the tool can read them back without a separate state file
- **Secure key handling**: `umask 177` is set before key generation and immediately restored; keys are generated in a `mktemp` directory that is deleted after use
- **Peer deletion via sentinel ranges**: each client block in the server config is wrapped in `# BEGIN PEER:name` / `# END PEER:name` markers, enabling a single `sed` range-delete with no line number arithmetic

Tools like Tailscale abstract all of this behind a SaaS control plane. The self-hosted equivalent requires handling every edge case explicitly.

### SVN hooks as a lightweight CI/CD system

The `svn` project implements two CI trigger patterns that modern tools expose as first-class features, built before those tools were widely available:

- **Keyword-in-commit-message trigger**: a developer opts into a Jenkins build by including "Jenkins" in their commit message — no web UI, no branch rule, the commit itself carries the intent
- **Version-file trigger**: touching `c_ver.c` (the firmware version file) unconditionally fires the corresponding product build — a natural proxy for "a release-worthy change was committed"

The `hooks-append.sh` migration script is also worth noting: when the MySQL logging line was added to the post-commit template after it had already been deployed to dozens of repositories, rather than redeploying all hooks (and potentially overwriting per-repo customisations), the script appended only the delta to each existing file in one pass. This is a surgical schema migration applied to a filesystem of shell scripts.

