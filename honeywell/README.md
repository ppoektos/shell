# Honeywell Access Control

Script to pull access events from a Honeywell security panel and load them into a MySQL visit database.

## Files

| File | Description |
|------|-------------|
| `honeywell.sh` | Downloads EventReport.csv from the panel, loads new rows into MySQL |
| `honeywell.php` | Web button to trigger honeywell.sh manually from a browser |
| `visit.php` | Web GUI — full event history, date-range arrival-band report, user filter |
| `visit1.php` | CSV export of the arrival-band report (same queries, streams download) |

## How it works

1. Authenticates to the Honeywell panel web interface at `<HONEYWELL_IP>` using a form POST, extracts the session cookie
2. Downloads `EventReport.csv` from the panel's upload endpoint
3. Reads the last known event ID from `lastEvent` file to find the cutoff row
4. Parses new rows: extracts date, direction (In/Out), and user display name
5. Bulk-loads the collected events into MySQL via `LOAD DATA INFILE` — single statement for the whole batch
6. Updates `lastEvent` to the latest event for the next run
7. Resolves user display names to internal user IDs via a `JOIN`-style `UPDATE` against the `users` table

## Setup

- `lastEvent` file must exist at `/root/scripts/lastEvent` with the text of the most recent known event
- MySQL must be configured to allow `LOAD DATA INFILE` from `/var/lib/mysql-files/`
- The panel must be reachable at `<HONEYWELL_IP>` from the host running this script

## Web GUI (visit.php)

`visit.php` is a five-panel dashboard backed by the `visit` MySQL database:

1. **Upload** — file upload form that accepts a new `EventReport.csv` and calls `loadevents.sh` to import it
2. **Full user report** — dropdown of all users, returns every checkpoint event for that person
3. **Date report** — date range picker, runs four parallel queries splitting first-arrivals into bands: 9:30–9:45, 9:45–10:00, 10:00–10:30, 10:30–18:00 — each band shown as a separate colour-coded table
4. **CSV export** — same date range, same four-band queries, output as a downloadable `export.csv` via `visit1.php`
5. **Date+User report** — per-person event list filtered by date range

The arrival-band breakdown is the core feature: it shows who arrived on time vs. late across a date range, grouped by how late they were.

## Notable patterns

**Cookie extraction via sed.** The login response header is piped through string parameter expansion (`${cookie##*:}` / `${cookie%%;*}`) to isolate the cookie value without any external tools.

**`LOAD DATA INFILE` for bulk insert.** Rather than looping N `INSERT` statements, all parsed events are written to a CSV file first, then loaded in a single MySQL statement. This is orders of magnitude faster for large event dumps and avoids per-row round-trips.

**Reverse order via `tac`.** Events in the CSV are newest-first; `tac` reverses them before parsing so the `lastEvent` marker after processing always points to the newest row.

**`MIN(date)` with `GROUP BY user_id, date(date)` for first-arrival-per-day.** The core SQL pattern in `visit.php` doesn't just filter by time range — it first collapses the checkpoint table to one row per person per calendar day (the earliest `in` event), then joins back to apply the time-band filter. Without the inner subquery, someone who badged in at 9:35, left at lunch, and came back at 14:00 would appear in the afternoon band instead of the morning one.

**Four parallel queries instead of one.** Rather than a single query with a `CASE` expression or application-side bucketing, `visit.php` runs four separate SQL queries — one per arrival band — and renders each as its own table. The result is that the PHP is almost trivially simple: run query, loop rows, echo HTML. The database does the classification; PHP just formats the output.

**`php://output` as a streaming CSV target.** `visit1.php` opens `fopen('php://output', 'w')` and writes CSV rows directly into the HTTP response body via `fputcsv`. No temp file, no buffering — the data goes straight from the database cursor to the browser download. `fputcsv` also handles quoting and escaping automatically, which a manual `implode(',', ...)` approach would not.

**jQuery UI datepicker with linked min/max.** The date range pickers in `visit.php` are wired so that selecting a "from" date automatically sets the "to" picker's minimum, and vice versa. This prevents impossible ranges without any server-side validation — the constraint is enforced entirely in the browser via two `onClose` callbacks.

**Two upload paths for the same data.** The system has two ways to get events in: `honeywell.sh` pulls from the panel directly over HTTPS, and `visit.php` accepts a manual file upload. The upload path calls `loadevents.sh` via `shell_exec` to process the file — the same bulk-load logic, triggered from a browser for cases where the panel is unreachable or events need to be replayed from a saved CSV.
