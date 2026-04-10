#!/bin/sh
# Called by post-commit hooks to send a plain-text commit notification email.
# Usage: svn-email.sh <REPOS> <REV> <SENDTO>

REPOS="$1"
REV="$2"
SENDTO="$3"
SENDFROM="<ROBOT_EMAIL>"
LIMITDIFF=200
CHANGELOG=`svnlook log -r $REV $REPOS`
AUTHOR=`svnlook author -r $REV $REPOS`
CHANGED=`svnlook changed -r $REV $REPOS`
DIFF=`svnlook diff -r $REV $REPOS | head --lines=$LIMITDIFF`
DATE=`date`
TMPFILE=/tmp/svn$REV-$RANDOM.txt
SUBJECT="$CHANGELOG"

echo "-------------------- SVN Commit Notification --------------------
Repository: $REPOS
Revision:   $REV
Author:     $AUTHOR
Date:       $DATE
-----------------------------------------------------------------
Comment: $CHANGELOG
-----------------------------------------------------------------
Changes: $CHANGED
-----------------------------------------------------------------
Diff:
$DIFF
" > $TMPFILE

/usr/bin/mutt -e 'set content_type="text/plain"' -a $TMPFILE -F /etc/Muttrc -s "$SUBJECT" -- $SENDTO < $TMPFILE

rm -f /tmp/svn*
