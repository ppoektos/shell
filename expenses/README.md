# Office Expenses

Tracks cash, expenses, and running balance for two offices. Employees enter expense records into a TWiki wiki page; a daily cron job parses the page, loads records into MySQL, and recalculates balances. A PHP page renders the full report by year.

## Files

| File | Description |
|------|-------------|
| `OfficeExpenses.txt` | TWiki EDITTABLE form — the browser UI employees use to submit expense entries |
| `expenses.sh` | Daily cron script — parses the TWiki file, inserts rows into MySQL, recalculates balances, clears the form |
| `expenses.php` | Web report — yearly summary table plus collapsible monthly detail per office |

## How it works

### Data entry

`OfficeExpenses.txt` is a TWiki wiki page with an `EDITTABLE` macro that renders as an interactive table with dropdowns (office, expense type, project flag) and text fields (description, person, amount). Employees visit the page in a browser and append rows. No custom form handler exists — TWiki itself is the UI.

### Daily processing (`expenses.sh`)

The script runs daily via cron and handles two distinct concerns:

**Month boundary (day 1 only):** Creates a new row in the `main` summary table, then for each office computes the opening balance as `prev_balance + prev_deposits - prev_expenses` using a MySQL subquery against last month's `exp` rows — all in a single `INSERT ... SELECT` statement. Also updates the default date in the `EDITTABLE` format string to the new month's first day so the date picker starts correctly.

**Expense ingestion (any day with data):** Filters the TWiki file down to data rows, extracts fields with `awk -F"|"`, inserts each row into the `exp` table, then wipes all processed rows from the wiki file with `sed -i '/^| 2/d'`. After ingestion, iterates over all affected months and recalculates `exp`, `cash`, and `balance` columns in the `main` summary table via three `UPDATE ... SELECT` statements.

### Web display (`expenses.php`)

Accepts a `?year=` GET parameter. Renders a top-level summary table (cash / expenses / balance per office per month), then for each office iterates all 12 months rendering a collapsible section per month. Each section shows per-category totals and transaction detail tables, plus a project-attributed spending summary for entries flagged with `ProjectSpecified = 1`.

## Database structure

Two tables in the `expenses` database:

- **`main`** — one row per month: `expense_date`, `office1_cash`, `office1_exp`, `office1_bal`, `office2_cash`, `office2_exp`, `office2_bal`. Denormalized summary; updated by the shell script after each ingestion.
- **`exp`** — one row per transaction: `date`, `branch`, `ExpType`, `description`, `resp`, `money`, `ProjectSpecified`, `ProjectNumber`. The `Balance` ExpType is a special row that carries forward the opening balance for each month.

## Notable patterns

**TWiki as a zero-code input form.** The `EDITTABLE` macro turns a plain wiki table into a browser form with typed columns — dropdowns for office and expense type, a date picker, text fields for the rest. No HTML, no PHP, no JavaScript was written for the input side. The wiki file on disk is the database input buffer.

**`sed '/^| /!d; /^| \*/d'` as a TWiki table parser.** Two chained sed deletions reduce the entire wiki file to just data rows: the first keeps only lines starting with `| ` (pipe-delimited rows), the second removes header rows starting with `| *` (bold cells). The result is a clean stream of expense entries — a complete table parser in one command.

**`sed -i '/^| 2/d'` as a self-clearing form.** After all rows are processed, a single `sed -i` wipes every line beginning with `| 2` (i.e., any date starting with `2`, covering all years from 2000–2999). The wiki page is left with only the header and the `EDITTABLE` macro — blank and ready for next month. The form resets itself; no separate cleanup job needed.

**`sed -i "${ln}c\..."` to rewrite a specific line.** On the first of each month, the script finds the line number of the `{format=...}` macro with `sed -n '/{format=/='`, then uses the `c\` command to replace that exact line with a new version containing the updated default date. This is a precise in-place line replacement — no temp files, no pattern matching ambiguity.

**`INSERT INTO exp ... SELECT prev_bal + prev_deposit - prev_expenses`** — balance carried forward in one statement. The opening balance for each new month is computed entirely inside a single MySQL `INSERT ... SELECT` using a derived table (`from (...) d`) that calculates three subquery values in parallel: last month's balance row, sum of deposits, and sum of non-balance/non-deposit expenses. The result lands directly as a new `Balance` row without any shell arithmetic.

**Dual storage of balance.** The opening balance appears in two places: as a `Balance`-typed row in the `exp` table (so it participates in per-month queries naturally) and as a `_bal` column in the `main` table (so the summary view requires no joins). The shell script writes both after each recalculation — redundant storage traded for query simplicity.

**`ConnectionString` as a pipe target.** The full MySQL client command is stored in `ConnectionString` and used throughout by piping SQL into it: `echo "INSERT ..." | $ConnectionString expenses`. This means the database host, credentials, and any flags are defined once at the top. Swapping the database server requires changing one line. The same pattern appears in the lunch-order project.

**`${Desc:-blank}` default substitution.** If an expense row has no description, the bash parameter expansion `${Desc:-blank}` substitutes the literal string `blank` instead of passing an empty string to MySQL. This prevents NULL values in the `description` column without any explicit `if` check.

**`: <<'END' ... END` as a manual override block.** A heredoc discarded by the null command `:` wraps a block of variable assignments (`offices=`, `year_start=`, `month_start=`, etc.) that override the auto-detected values. To replay historical data, an operator uncomments this block, sets the desired range, and re-runs the script. The comment in the script above the block (`# set comment for manual update`) signals exactly where to cut.

**Multi-year nested loop for recalculation.** After ingestion, the script iterates `for y in year_start..year_current; for m in month_start..12` and resets `month_start=1` at the year boundary. This correctly handles spans that cross a year boundary (e.g., November 2019 to March 2020) without any date arithmetic library — just three nested loops and a break condition.

**`date +%-m --date="$3-$2-14 -1 month"`** for safe previous-month arithmetic. To find the previous month from an arbitrary year/month pair, the script constructs a date string anchored on the 14th (`$3-$2-14`) before subtracting one month. Using the 14th avoids the off-by-one error that occurs when subtracting a month from the 31st (e.g., `2019-03-31 -1 month` would give `2019-03-03` on some systems). The 14th is always safe.

**PHP collapsible month sections without JavaScript.** The `toggleWrapper` / `toggleInner` div pattern relies on CSS `display: none` toggled by a click handler on the `clicker` span — the markup is purely structural. All 12 months are rendered server-side in one pass; the browser collapses them. No AJAX, no partial rendering.

**`date('F', mktime(0, 0, 0, $i, 1))`** for locale-safe month names. PHP's `mktime` constructs a timestamp for the first of month `$i`, and `date('F', ...)` formats it as the full English month name. No hardcoded array of month names, no locale dependency — one expression covers all 12.

**Daily file snapshot as an audit log.** Before processing, `cp $File /root/expenses/$dts.txt` saves a dated copy of the TWiki file. Since the script wipes processed rows from the live file, this copy is the only record of what was submitted on that day. The `/root/expenses/` directory becomes an append-only archive of daily submissions without any dedicated logging infrastructure.
