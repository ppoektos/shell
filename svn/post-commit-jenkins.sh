#!/bin/sh
# SVN post-commit hook — multi-product Jenkins variant.
# Logs the commit to the DB, then fires a Jenkins build if a version
# file (c_ver.c) in one of the tracked product trees was changed.
# No keyword required in the commit message — the changed path is the trigger.

REPOS="$1"
REV="$2"
SVNLOOK=/usr/bin/svnlook
AUTHOR=`svnlook author -r $REV $REPOS`
CHANGELOG=`svnlook log -r $REV $REPOS`

echo "INSERT INTO commits (user,url,log) VALUES ('$AUTHOR', '${REPOS##*/}', '${CHANGELOG//\'/''}');" | mysql --login-path=<DB_LOGIN_PATH> svn

$SVNLOOK changed -r "$REV" "$REPOS" | grep -q "<PRODUCT1>/App SW/Trunk/<PRODUCT1>/c_ver.c"
if [ "$?" -eq "0" ]; then
  /usr/bin/wget -q -O /dev/null "http://<JENKINS_HOST>/view/<JENKINS_VIEW>/job/<JENKINS_JOB1>/build?token=<JENKINS_TOKEN1>"
fi

$SVNLOOK changed -r "$REV" "$REPOS" | grep -q "<PRODUCT2>/App SW/Trunk/<PRODUCT2>/c_ver.c"
if [ "$?" -eq "0" ]; then
  /usr/bin/wget -q -O /dev/null "http://<JENKINS_HOST>/view/<JENKINS_VIEW>/job/<JENKINS_JOB2>/build?token=<JENKINS_TOKEN2>"
fi
