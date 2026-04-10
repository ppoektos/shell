# Confluence Automation

Scripts for automating Confluence project space management, weekly reporting, HR analytics charts, QA document index, and FlexLM license server restarts. All scripts talk to Confluence via `api.sh` — a thin curl wrapper around the Confluence REST API.

## Files

| Path | Description |
|------|-------------|
| `api.sh` | Shared Confluence REST wrapper — used by all other scripts |
| `space-creator/spacecreate.sh` | Creates a full project space with all standard pages from JSON templates |
| `space-creator/templates/*.json` | Confluence page templates (27 files) |
| `ipr/iprcreate.sh` | Weekly IPR page creator — copies last week's report for each active project |
| `ipr/iprfix.sh` | Scans last week's IPRs for an unfilled macro and auto-removes it |
| `ipr/check_report.sh` | Lists projects where PM or TL hasn't confirmed their IPR |
| `charts/chart.sh` | Weekly project hours chart — pulls from Redmine, pushes to Confluence |
| `charts/chart_month.sh` | Monthly variant of the project hours chart |
| `charts/chart_pe.sh` | Monthly Productivity/Efficiency/PE charts per team, department, and person |
| `charts/chart_dev_pe.sh` | Dev-focused PE chart with month-over-month diff highlighting |
| `qa-index/qa.sh` | Generates QA document index from NAS filesystem, pushes to Confluence |
| `qa-index/qa1` | Static JSON header for the QA index page |
| `qa-index/start_qamonitor.sh` | One-time setup — registers all NAS directories as incron watches on the QNAP |
| `qa-index/update_qamonitor.sh` | incron entry point on the QNAP — handles inotify events, self-updates watch list, triggers `qa.sh` on released file changes |
| `license-restart/resorcad.sh` | SSHes to a license server and safely restarts lmgrd |
| `license-restart/orcad.php` | Web UI to trigger resorcad.sh for two license servers |
| `space-creator/spcreate.php` | Web form to trigger spacecreate.sh from a browser |

## How it works

### `api.sh`

Wraps `curl` calls to `http://<CONFLUENCE_HOST>/rest/api/content`. Supports: `post`, `get`, `version`, `author`, `webui`, `delete`, `child`. Uses `~/.netrc` for credentials (`-n` flag). All other scripts source or call this directly.

### Space creator

`spacecreate.sh` takes a project name as argument, auto-generates a unique space key from name initials, creates the space, then POSTs all template JSON files in the right hierarchy:

```
dsl  →  ip, rs, sdd, hdd, qcsd, te, tt, pr
d    →  (design section index)
m    →  ce, sch, cc, fin, mom, psr, ep, ipr, gate → gateR, gateD, gateDV
to   →  (technologies overview)
```

Each template's `ancestors.id` and `space.key` are rewritten in-place by `sed` before posting, so the same files are reused for every new space.

### IPR automation

Each Friday, `iprcreate.sh`:
1. Reads a Confluence page listing active project IDs (`<PAGE_ID_PROJECTS>`)
2. For each project, finds its space and the IPR root page
3. Copies last week's report, resets all task checkboxes to `incomplete`, clears name fields
4. Labels the new page `newipr`
5. In January, archives the previous year's reports under a `YYYY` parent page

`iprfix.sh` runs separately and finds any report still containing the `internal_project_report_name` macro (meaning PM/TL forgot to fill it in). It removes the macro via PUT and emails a list of offenders.

`check_report.sh` takes `PM` or `TL` as argument and lists projects where that role left their section `incomplete`.

### Charts

All four chart scripts:
- Query a Redmine/effort MySQL database (via `--login-path=<DB_NAME>`)
- Build Confluence chart macro markup dynamically using heredoc + `cat` concatenation
- PUT the result to a specific Confluence page

`chart_pe.sh` and `chart_dev_pe.sh` use an `effort` database with `users`, `teams`, `depts` tables containing per-person monthly Productivity, Efficiency, and PE values.

### QA index

The QA index system spans two machines. On the QNAP NAS, `start_qamonitor.sh` is run once to seed `/etc/config/incron.d/qamonit.conf` with an inotify watch per directory under `/share/qa_admin/`. After that, `update_qamonitor.sh` is the incron entry point — it receives three arguments from incron (`$@` = path, `$#` = filename, `$%` = event mask) and handles four cases:

- **New directory** — appends a new watch entry and restarts the incron daemon, so the monitor is self-extending as the document tree grows.
- **Deleted directory** — removes the matching line from the config via `sed -i` and restarts incron.
- **File written or deleted matching `*_released*`** — SSHes to the Confluence server and fires `qa.sh`.
- **Anything else** — exits silently.

`qa.sh` (running on the Confluence server) mounts the NAS share, walks directories matching an 8-char code pattern (`MMSSSSSS`), finds `*_released*` files, copies them to an nginx web root, and builds an HTML table. The result is prepended with the static `qa1` header and PUT to Confluence.

The full pipeline: NAS filesystem change → incron on QNAP → `update_qamonitor.sh` → SSH → `qa.sh` → Confluence page update.

### License restart

`resorcad.sh $hostname` SSHes to `lic.$hostname` and runs a safe lmgrd restart: stop → wait 61 seconds → start. The 61-second wait is the FlexLM-recommended safe window to ensure all checked-out licenses are released before the daemon process exits.

`orcad.php` is the browser front-end: two submit buttons, one per license server hostname. Each calls `resorcad.sh` via `shell_exec('sudo ...')` and streams the SSH output back inline as `<pre>` text. `spcreate.php` does the same for `spacecreate.sh` — a text field for space name and optional description, submit triggers the shell script, full output shown in the page.

## Notable patterns

**`api.sh` as a Unix filter.** Every script calls `./api.sh get <PAGE_ID> | grep value | grep -oE ...` — the API wrapper is just a pipe stage. Page content arrives as JSON, gets piped through `python -mjson.tool` for pretty-printing, then filtered with standard text tools.

**In-place template mutation.** `spacecreate.sh` uses `sed -i` to rewrite `ancestors.id` and `space.key` inside each `.json` template before posting. The same 27 files serve every new project space — the script patches the IDs into them at runtime.

**`eval` for indirect array lookup.** The root-to-children mapping (`dChild`, `mChild`) uses `eval Root="$"${RootPage}Child` to expand variable names dynamically. Each root page name becomes a variable name prefix that resolves to its child list.

**Report cloning via sed pipeline.** `iprcreate.sh` fetches last week's IPR body as a JSON string, pipes it through a multi-stage `sed` that resets checkbox states, clears author mentions, and removes challenge text — then wraps the result in a new JSON envelope and POSTs it. No template file needed; the previous report is the template.

**Month-over-month diff as HTML colour.** `chart_dev_pe.sh` compares each month's PE value to the previous month and injects `highlight-green` or `highlight-red` Confluence table cell classes directly into the JSON payload. The colouring happens in the shell, not in Confluence macros.

**Dynamic Y-axis scaling.** Before generating each chart, `chart_dev_pe.sh` runs a pre-pass query to collect all values, sorts them in bash, and rounds up/down to the nearest 10 for `rangeAxisUpperBound`/`rangeAxisLowerBound`. The chart always fits the data without manual adjustment.

**`python -mjson.tool` as a universal JSON parser.** No `jq`, no dependencies — every script pipes curl output through `python -mjson.tool` for pretty-printing, then filters with `grep` and `awk`. The Python standard library becomes a JSON formatter available on any machine that has Python, which in 2017 was everything.

**`~/.netrc` for credential-free scripts.** All curl calls use the `-n` flag, which tells curl to read credentials from `~/.netrc` by hostname. No username or password appears anywhere in any script — the auth lives in a file that never gets committed. The scripts are safe to share; the secrets file stays on the server.

**Space key generation from initials.** `spacecreate.sh` derives the Confluence space key from the project name using `sed -e 's/\(.\)[^ ]* */\1/g'` — this regex keeps only the first character of each word, producing an acronym. "00001111 - New Project Name" becomes `0NPN`. If that key already exists, a counter suffix is appended in a `while` loop until uniqueness is confirmed via the API.

**Split heredoc around a variable loop.** Chart scripts can't put a shell loop inside a heredoc, so they split the JSON payload across two temp files: `chart1` (the heredoc opening) and `chart2` (the closing), with the loop writing rows to neither — then `cat chart1 chart2` merges them. A simple workaround for heredoc's inability to contain dynamic content mid-stream.

**`iprfix.sh` rewrites its own server URL.** The search result URLs returned by Confluence contain the public hostname. Since `iprfix.sh` runs on the same machine as Confluence, it pipes those URLs through `sed` to replace the public hostname with `localhost:8090` before making further requests — avoiding a round-trip through DNS and the load balancer for internal calls.

**Self-extending incron watch list.** `update_qamonitor.sh` handles `IN_CREATE,IN_ISDIR` by appending the new directory to the incron config and restarting the daemon — so the watch list grows automatically as new project folders are created on the NAS. No manual re-registration needed; the monitor bootstraps itself forward. The inverse (`IN_DELETE,IN_ISDIR`) prunes the entry via `sed -i` to keep the config clean.

**`shell_exec` as a web-to-shell bridge.** Both `orcad.php` and `spcreate.php` use PHP's `shell_exec('sudo ...')` to delegate directly to shell scripts. The web server runs as a low-privilege user; `sudo` grants it targeted escalation for exactly one command. The full SSH or script output is returned as a string and rendered in `<pre>` tags — the browser becomes a terminal for a long-running operation.
