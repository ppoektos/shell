# Effort Tracking

A collection of shell scripts for tracking developer productivity, efficiency, and time spent across multiple office locations. The system is built around a Redmine time-tracking database (`<REDMINE_DB>`) and a separate `effort` database that stores computed monthly metrics. Reports are delivered via `mutt` email and Google Charts HTML attachments.

> The `effort` database is also consumed by the Confluence chart scripts in the [confluence](../confluence) project (`charts/chart_pe.sh`, `charts/chart_dev_pe.sh`), which read the stored productivity/efficiency values and push visualisations to Confluence pages.

---

## Files

| File | Description |
|------|-------------|
| `notifications/effort.sh` | Main entry point: dispatches weekly, monthly, total productivity, and accountant reports |
| `notifications/effortfunc.sh` | Core library: all metric functions (invoiceable, noninvoiceable, sales, holiday, productivity, efficiency, DB upsert) |
| `notifications/timeReport.sh` | Daily/weekly/monthly timesheet reports and Google Charts pie-chart generation per developer |
| `notifications/compareDate.sh` | Debug utility: shows how Start/Finish day custom fields affect nominal working hours for a list of users |
| `notifications/costBracket.sh` | Reads active projects from Confluence, then reports spent hours broken down by employee cost bracket (week/month) |
| `notifications/export_rate.sh` | Per-version breakdown of hours by cost bracket across active projects; supports per-user rate override |
| `notifications/moveTLC.sh` | Office move tracker: queries all issues in a Redmine project and emails an HTML status table to project members |
| `notifications/covid.sh` | Split-team daily/weekly timesheet used during COVID remote-work period (separate report per sub-group) |
| `notifications/join.awk` | AWK two-file join: annotates HTML table rows with a label from a dictionary file |
| `notifications/head` | HTML email header template with jQuery Mobile 1.4.5 for mobile-friendly report rendering |

---

## How it works

### Effort calculation (`effort.sh` / `effortfunc.sh`)

`effort.sh` is invoked from cron with one of four modes (`week`, `month`, `total`, `accountant`). For `total` mode it sources `effortfunc.sh` and calls `main`, which iterates over all team members. For each user the following metrics are computed and then upserted into the `effort` database:

- **Registered hours** — raw sum from `time_entries`
- **Invoiceable hours** — hours on projects matching `3[0-1]0[1-6].*` naming pattern (client-billable)
- **Non-invoiceable hours** — hours on internal R&D / QA / department activity projects
- **Sales, Meeting, PMO, Ill, Holiday** — hours filtered by Redmine activity type or project name
- **Productivity** = `(registered - holiday) / (nominal - holiday) * 100`
- **Efficiency** = `invoiced / (registered - holiday) * 100`
- **Prod×Eff** = product of the two above

The `UpdateMysql=true` flag controls whether results are written to the database. Setting it to blank turns the run into a dry-run recalculation — results are printed but not persisted.

### Time reporting (`timeReport.sh`)

Supports `daily`, `weekly`, `monthly`, and `chart` modes. The `daily` mode calls three functions in sequence: `zero` (who has no hours), `projects` (hours per active project), `dprtmnts` (per-team breakdown). The `chart` subcommand generates standalone HTML files with embedded Google Charts `PieChart` JavaScript — one dual chart per user (project breakdown + project-vs-non-project ratio) — and emails them as attachments.

### Cost bracket reporting (`costBracket.sh` / `export_rate.sh`)

`costBracket.sh` fetches the list of active projects from a Confluence page via the REST API, then for each project queries time grouped by the custom-field `possible_values` (cost brackets: UA employees, UA junior employees, DK employees). Reports cover the current week (and optionally bi-week), current year, and all-time total in a single HTML table.

`export_rate.sh` drills down to the version level within each project, accumulating hours per cost bracket, with an override mechanism for specific users on specific projects (`shopt -s extglob` / `case $override_users`).

### Utilities

- **`compareDate.sh`** — standalone diagnostic: for a hardcoded list of users it traces how Redmine `Start day` / `Finish day` custom fields map to working-day ordinals and thus affect nominal hours; uses `ncal -hMm` to enumerate weekdays.
- **`join.awk`** — processes two files: the first builds a `dict[key]=value` map; the second file's rows are annotated with `key(value)` on key-change. Field separator is `</td><td>`, making it operate directly on HTML table rows.
- **`covid.sh`** — used during the period when teams split across locations; generates separate per-sub-group timesheets sent to different recipients, with an inline `proj` function that queries distinct project names for each user.
- **`moveTLC.sh`** — queries all issues in a named Redmine project ordered by due date, renders a colour-coded HTML table (red for `New` status), and emails to the project's member list dynamically built from `members` table.

---

## Notable patterns

1. **`calc()` as an AWK calculator.** The one-liner `calc () { awk "BEGIN { print $*}"; }` is used everywhere floating-point arithmetic is needed in shell. Because `$*` expands before AWK sees the string, the shell composes the full arithmetic expression and AWK evaluates it — enabling expressions like `calc $sum+$hours` without any external `bc` dependency.

2. **`eval` for indirect variable dispatch.** `effortfunc.sh` and `timeReport.sh` use `eval department="$"${department_temp}_table` and similar patterns to address dynamically named variables (`PM_table`, `TL_table`, …) without arrays. This is the classic Bash indirect expansion idiom predating `${!varname}`.

3. **`init_vars` with `eval` loop for zero-initialisation.** Rather than declaring dozens of `team_prod=0; team_eff=0; …` lines, `init_vars` iterates a cross product of value names × activity names and calls `eval "${val}_${act}=0"`. This makes adding a new activity type a one-token change.

4. **Holiday pro-rating with Start/Finish day boundary logic.** The `nominalworkdays` function uses `cal -m` / `ncal -hMm` to enumerate the actual working days of the previous month, then finds the ordinal position of the user's start/finish date within that sorted list. The `holiday` function then only counts holidays that fall *between* those ordinals — so a user who started on the 20th is not penalised for a holiday on the 5th. The three cases (start only, finish only, both) are handled separately with `[[ -n ]]` / `[[ -z ]]` guards.

5. **DK vs UA nominal hours difference.** Ukrainian employees work 8 h/day, Danish employees 7.4 h/day (37-hour week ÷ 5). This is baked in explicitly: `user_nominal=$(echo "$WorkDays $hol 7.4" | awk '{print ($1 - $2) * $3}')` for `office3`/`office4`, while UA uses integer arithmetic `$((($WorkDays - $hol) * 8))`. One DK user in the PM group has a 28.5 h/week contract (5.7 h/day), handled as a named case.

6. **Confluence REST API as a project registry.** Both `timeReport.sh` and `costBracket.sh` fetch the authoritative list of active projects from a Confluence page body via `curl -sn https://<CONFLUENCE_HOST>/rest/api/content/<PAGE_ID_PROJECTS>?expand=body.storage`, then extract 8-digit project IDs with `grep -oE '[0-9]{8} - [a-zA-Z0-9 -]*'`. This avoids maintaining a separate configuration file — the wiki page *is* the config.

7. **`ON DUPLICATE KEY UPDATE` upsert pattern.** Every monthly recalculation upserts into `users`, `teams`, and `depts` tables using MySQL's `ON DUPLICATE KEY UPDATE … VALUES(col)` shorthand. This means the same cron job can be re-run to correct historical data simply by adjusting `MysqlDateMonth` and `PastMonth` at the top of `effortfunc.sh` without any delete/re-insert logic.

8. **Dynamic Google Charts generation via split heredoc.** `timeReport.sh` builds each HTML chart file by interleaving `cat >> file <<EOF` heredoc blocks with shell loops. The Google Charts `DataTable.addRows([…])` array is populated line-by-line inside the loop body, then the closing options block is appended by another heredoc. Each user gets two charts: a per-project pie and a project-vs-non-project summary, all in one pass.

9. **Array-based comma-joined project ID lists.** Functions like `noninvoiceable_projects`, `sales_projects`, and `meeting_projects` build Bash arrays of MySQL project IDs, append a trailing comma to each element with `${arr[@]/%/,}`, strip the last comma via index arithmetic, then interpolate the result directly into an `IN (…)` clause. This avoids any string-join utility and works with arrays of arbitrary length.

10. **`join.awk` HTML-aware two-file join.** By setting `FS = "</td><td>"`, the AWK script splits on HTML table cell boundaries, making `$1` the first cell (login) and `$2` the second (name). The first file populates a `dict` map; subsequent files are annotated on key change. The `END` guard with a trailing space forces the final row to be flushed. This lets shell scripts augment an HTML table with a second dataset without a database join or temp files.

11. **`shopt -s extglob` for per-user rate override in `export_rate.sh`.** The script uses an extended glob pattern `@(opo|rmi)` stored in a variable `override_users`, then matches inside a `case` statement. This is the portable Bash way to do multi-value case matching without a regex engine, and it elegantly solves the problem of a small set of users needing a different cost bracket assignment on specific projects.
