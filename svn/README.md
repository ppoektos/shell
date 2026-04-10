# SVN

SVN hook scripts, commit logging, daily reporting, and hook management utilities for a multi-repository SVN server integrated with Redmine and Jenkins.

## Files

| File | Description |
|------|-------------|
| `svn-email.sh` | Sends a plain-text commit notification email with author, changed paths, and a diff (capped at 200 lines) |
| `pre-commit.sh` | Pre-commit hook — rejects commits whose log message contains no alphanumeric characters |
| `post-commit.sh` | Base post-commit hook template — sends email via `svn-email.sh` and logs the commit to a MySQL `commits` table |
| `post-commit-keyword.sh` | Post-commit variant — additionally fires a Jenkins build if a specific board SW path was touched AND the commit message contains the keyword "Jenkins" |
| `post-commit-jenkins.sh` | Post-commit variant — fires per-product Jenkins builds when a version file (`c_ver.c`) changes; no keyword required |
| `hooks-copy.sh` | Mass-deploys `post-commit` and `pre-commit` to every repo `hooks/` directory that is missing them |
| `hooks-append.sh` | Retrofits the DB INSERT statement to all existing post-commit hooks without redeploying the entire file |
| `daily-report.sh` | Queries today's commits and emails separate HTML reports to SW and HW team leads; includes a dedicated section for a BOM tool repo |

## How it works

### Redmine auto-provisioning (`reposman.rb`)

A cron job runs Redmine's bundled `reposman.rb` every 30 minutes. It queries the Redmine API and creates a new SVN repository under `/mnt/svn` for every Redmine project that does not have one yet, setting ownership to the Apache user. A second cron job runs `Repository.fetch_changesets` nightly to pull commit history into Redmine's timeline and activity views.

```
*/30 * * * *  root  reposman.rb --redmine https://<REDMINE_HOST> --svn-dir /mnt/svn --owner apache --url http://<SVN_HOST>/svn/
0    4 * * *  root  rails runner "Repository.fetch_changesets" -e production
```

### Hooks (`pre-commit.sh`, `post-commit.sh`, variants)

`pre-commit.sh` runs `svnlook log` on the transaction and greps for any alphanumeric character. If the message is blank or whitespace-only it exits 1, which SVN treats as a rejection.

`post-commit.sh` is the base template deployed to most repositories. It calls `svn-email.sh` for the notification email, then pipes a raw `INSERT` statement into `mysql` to record the commit in the `svn.commits` table. The `${REPOS##*/}` expansion strips the full path, keeping only the repository name. Single quotes in the commit message are neutralised with `${CHANGELOG//\'/''}` before embedding in the SQL string.

`post-commit-keyword.sh` is used on repositories where developers can opt into a Jenkins build by including the word "Jenkins" in their commit message. The hook checks both the changed path (board SW tree) and the log message before firing. A developer can therefore trigger a build without any web UI access.

`post-commit-jenkins.sh` is the path-only variant used for product repositories. It watches for commits to a version file (`c_ver.c`) inside each product's trunk. Any commit that touches that file triggers the corresponding Jenkins job unconditionally — no keyword needed.

### Hook management (`hooks-copy.sh`, `hooks-append.sh`)

When the post-commit template was first written, `hooks-copy.sh` mass-deployed it to all repositories lacking a hook. The script uses `find . -type d -name hooks` to iterate and skips repos that already have a `post-commit` in place — so it is safe to re-run.

When the MySQL logging line was added to the template after deployment, rather than redeploying all hooks, `hooks-append.sh` appended only the new block to every existing file. This preserved any per-repo customisations while adding the new capability in one pass.

Both scripts are run from the SVN repository root (`/mnt/svn`) and operate on every repository tree below it.

### `daily-report.sh`

Runs as a cron job each evening. Queries the `svn.commits` table (populated by post-commit hooks) for today's commits, splitting the result into two groups by username: SW developers and HW developers. For each group it builds an HTML `<table>` and sends it to the respective team lead.

The report also cross-checks the BOM cost calculation tool repository. A `SELECT COUNT(*)` query with `url LIKE '%bom%'` determines whether any commits landed there today. Zero commits triggers a fixed "developers were lazy today" message; a non-zero count appends a second table with those commits.

The HTML email is assembled by concatenating pre-built header templates (`top.sw`, `top.hw`) with the generated rows and a footer. Names of developers who committed are removed from the header template with `sed -i "s/ ${user},//"` as each row is processed — so by the time the email is built, only non-committers remain in the expected-list header.

## Notable patterns

**Commit message as CI trigger.** `post-commit-keyword.sh` uses `svnlook log | grep -q "Jenkins"` to let a developer opt into a Jenkins build by including a word in their message. No web UI, no separate trigger button — the commit itself carries the intent.

**Version file as CI trigger.** `post-commit-jenkins.sh` watches for changes to `c_ver.c`. This file is only touched when a developer bumps the firmware version, making it a natural proxy for "a release-worthy change was just committed." No keyword, no flag — the file path is the signal.

**`${REPOS##*/}` to strip the repo path.** SVN passes the full filesystem path of the repository as `$REPOS`. Storing the full path in the DB is fragile; `${REPOS##*/}` keeps only the directory name (the repo's logical name) for the `commits.url` column.

**SQL injection defence in bash.** `${CHANGELOG//\'/''}` replaces any single quotes in the commit message before it is embedded in the SQL INSERT string. A poor man's escape, but it protects against accidental breakage from commit messages that include apostrophes.

**`hooks-append.sh` as a surgical retrofit.** Rather than redeploying all hooks when a new line was added to the template, the append script adds only the delta to every existing file. This is idempotent-safe because the check is at the tool level (re-running appends again), but in practice it was a one-shot migration.

**Header mutation as a presence indicator.** `daily-report.sh` copies the header template to a temp file, then uses `sed -i "s/ ${user},//"` to remove each committer's name as their row is processed. The template doubles as the expected-committers list; who remains in the header after processing is exactly who did not commit today.

**Absence detection via COUNT.** Rather than scanning URLs in the shell, the script runs `SELECT COUNT(*) WHERE url LIKE '%bom%'` and branches on whether the result is zero. The database does the detection; the shell just switches on the integer.

**Redmine-driven repository provisioning.** `reposman.rb` polls Redmine every 30 minutes and creates filesystem SVN repositories for new projects automatically. The repository lifecycle (creation, access URL) is fully driven by the project management tool — a developer creates a Redmine project and the VCS repository appears without any sysadmin action.
