#!/bin/sh
# SVN pre-commit hook — rejects commits with no log message.
# Deploy to every repository's hooks/ directory.
#
# Mass-deploy to all repos on the server:
#   find . -type d -name hooks | xargs -n 1 cp -p pre-commit.sh

REPOS="$1"
TXN="$2"

SVNLOOK=/usr/bin/svnlook
$SVNLOOK log -t "$TXN" "$REPOS" | \
   grep "[a-zA-Z0-9]" > /dev/null

GREP_STATUS=$?
if [ $GREP_STATUS -ne 0 ]
then
    echo "Repository's modifications are strictly prohibited without comments." 1>&2
    echo "Please write what you have done in this commit." 1>&2
    exit 1
fi
exit 0
