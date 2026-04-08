# Lunch Order System

Automated daily lunch ordering for multiple companies sharing a catering
arrangement. Reads employee choices from a TWiki wiki table, places orders
with the catering supplier via email, tracks orders in MySQL, and provides
a web reporting UI.

## Files

| File | Description |
|------|-------------|
| `lunchorder.sh` | Daily ordering script, runs at 12:15 on weekdays |
| `monthrep.sh` | Monthly summary report emailed to managers |
| `loadorders.sh` | One-off helper to back-fill historical orders into MySQL |
| `lunchorderbody.txt` | Email body template sent to catering supplier |
| `LunchOrdering.txt` | TWiki page template — the UI employees interact with |
| `lunch-report.php` | Web report — weekly order history by company |
| `count_weeks.sh` | Weekly lunch-order statistics by tenant group over the current year |
| `cron` | Cron schedule |

## How it works

Each weekday at 12:15 `lunchorder.sh` reads `LunchOrdering.txt` — a TWiki
wiki page where employees set `yes`/`no` for each day of the week. It then:

1. Parses the wiki table to collect that day's `yes` votes
2. Inserts each order into MySQL
3. Applies minimum order rules — 0 or 1 person: order cancelled; exactly 2: a
   VirtualPerson is added to meet the supplier's minimum of 3
4. Assigns orders to company groups for billing split
5. Emails the catering supplier and the office manager
6. Resets all `yes` → `no` in the wiki table for the next week
7. On Friday, orders for Monday instead of the next day

Failed MySQL inserts go to a deferred queue file and are retried automatically
on the next run.

## TWiki table format

`LunchOrdering.txt` is a TWiki wiki page with `EDITTABLE` macros that render
as interactive dropdowns in the browser. Employees visit the page and toggle
their days. The script reads the raw `.txt` file directly from the filesystem —
it filters rows starting with `| `, skips header rows starting with `| *`,
and extracts the person name (column 1) and the day's choice (column N).

Each company has its own section in the table. Guest rows use a naming
convention (`Company1_guestname`) so the script can assign them to the
correct billing group.

## `loadorders.sh` — historical back-fill helper

A one-off migration script. When MySQL tracking was introduced mid-operation,
historical orders existed only in the `dayperson` flat log file
(`/root/report/dayperson`) — one line per day listing who ordered.
`loadorders.sh` was written to parse that log for a specific past month,
extract dates and usernames, and insert them into MySQL retroactively so
the reporting UI had complete history from day one.

It is not part of the regular workflow — it was run once and kept for
reference.

## Companies and groups

Multiple companies share the catering arrangement. Each order is tagged with
a group ID for billing split:

| Group | Description |
|-------|-------------|
| company1 / guest_company1 | Company1 regulars and guests |
| company2 / guest_company2 | Company2 regulars and guests |
| company3 | Company3 guests |
| company4 | Company4 (special individual billing) |
| company5 / guest_company5 | Company5 |

The PHP reporting page colour-codes rows by company group for easy reading.

## Notable tricks

**TWiki as a form backend without a form backend.** The `EDITTABLE` macro
turns a plain wiki table into a web UI with dropdowns — no custom HTML, no
form handler, no JavaScript. The script then reads the raw `.txt` file
directly from the filesystem, bypassing the wiki entirely. TWiki is used
purely as a convenient editor for a structured text file.

**Wiki mutation as state reset.** After processing, the script rewrites the
wiki file in-place using `awk`, flipping all `yes` → `no`. This means the
wiki page itself is the state — no separate "processed" flag, no database
field. The file on disk is always ready for the next week's input.

**The VirtualPerson trick.** Rather than negotiating a lower minimum with
the supplier or cancelling orders, the script silently adds a fake person
when exactly 2 people order, making it appear as 3. The supplier gets a
valid order, the two real people get their lunch, and the extra cost is
absorbed internally. A pragmatic workaround encoded directly in the script.

**Deferred queue as a flat file.** Instead of a retry table in MySQL (which
would require MySQL to be up), failed inserts are written to a plain text
file — one `user date` pair per line. On the next run the file is read
line by line, retried, and successful lines are deleted with `sed -i '1d'`.
No database needed to survive a database outage.

**`dayperson` as an audit log.** Every day's orders are appended to a flat
log file, independent of MySQL. This meant historical data survived before
the database was introduced, and `loadorders.sh` could reconstruct any past
month from it. The log is effectively an append-only ledger that predates
the reporting infrastructure built on top of it.

## Shell tricks

**Connection string as a variable.** The full MySQL command including host,
user and password is stored in `$ConnectionString` and used by piping SQL
into it: `echo "INSERT ..." | $ConnectionString`. This lets the same command
appear once at the top and be reused throughout without repetition — and
swapping the database requires changing one line.

**Boolean variable used as a command.** `SendOrder=true` and `SendOrder=false`
are not flags or strings compared with `[ ]` — they are the actual shell
builtins `true` and `false`. So `if $SendOrder; then` directly executes the
variable's value as a command. Clean and idiomatic bash.

**Parallel array parsing in one pass.** `ChoiceArray` and `PersonArray` are
built from two separate `awk` calls on the same file, then iterated together
by index. This avoids complex multi-field parsing — each array does one job,
and the index keeps them in sync.

**`${PersonYes%%,}` — stripping the trailing comma.** The loop builds the
person list by appending `name,` each time. At the end `%%,` strips the last
trailing comma in one parameter expansion, no `sed` or subshell needed.

**Atomic file replacement.** The wiki file is never edited in place directly.
`awk` writes to a temp file, then `mv $Tmp $File` replaces it atomically.
If `awk` fails mid-write the original is untouched. The `mv` then also
restores ownership with `chown` in the same line using `&&`.

**`-s` to test non-empty file.** `[ -s $Path/deferred ]` checks that the
deferred file exists *and* is non-empty in one test. No need to check
existence and size separately — if the file is empty or missing, nothing
happens.

**MySQL as a Unix pipe target.** MySQL is never called via a library or
connector — SQL is just echoed into stdin and piped directly into the `mysql`
CLI. This means any shell variable can be interpolated into SQL naturally,
multi-statement batches are just multiline strings, and the exit code of the
pipe reflects query success or failure. The database client becomes just
another Unix filter.

**MySQL as the business logic layer.** The script does almost no group
assignment logic itself — it delegates it entirely to SQL. A single
multi-statement batch of `UPDATE ... JOIN` queries resolves every user to
their company group in one shot, using the `users` table as a lookup. Guests
who have no `users` record fall through to group 3 (unassigned), then get
reassigned by name prefix matching (`LIKE '%Company1_%'`). So the database
is not just storage — it is where the billing classification actually happens.
The shell feeds it raw inserts and lets SQL do the relational work.

**Hardcoded column numbers in the `case` statement.** The day-of-week
dispatch passes a column index directly to `awk` — Mon=4, Tue=5, Wed=6,
Thu=7, Fri=3. These numbers are the literal column positions in the TWiki
pipe-delimited table (`| Name | Mon | Tue | Wed | Thu | Fri |`), with
Friday being column 3 because it maps to the *next* working day which is
Monday — so Friday actually reads column 3 (Monday's column) of the
*following* week. Anyone reading just the `case` block without that context
would find the numbers opaque. It works, but it is entirely implicit
knowledge baked into integer literals.
