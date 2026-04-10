#!/bin/sh
# SVN post-commit hook — base template.
# Sends commit notification email and logs the commit to the DB.
# Deploy to every repository's hooks/ directory.

REPOS="$1"
REV="$2"
SENDTO="<COMMIT_NOTIFY_EMAILS>"

/mnt/svn/svn-email.sh "$REPOS" "$REV" "$SENDTO"

AUTHOR=`svnlook author -r $REV $REPOS`
CHANGELOG=`svnlook log -r $REV $REPOS`
echo "INSERT INTO commits (user,url,log) VALUES ('$AUTHOR', '${REPOS##*/}', '${CHANGELOG//\'/''}');" | mysql --login-path=<DB_LOGIN_PATH> svn
