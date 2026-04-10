#!/bin/sh
# SVN post-commit hook — keyword-triggered Jenkins variant.
# Sends commit email, logs to DB, and optionally fires a Jenkins build
# if the commit touched a specific board SW path AND the log message
# contains the word "Jenkins".

REPOS="$1"
REV="$2"
SENDTO="<COMMIT_NOTIFY_EMAILS>"
SVNLOOK=/usr/bin/svnlook

/mnt/svn/svn-email.sh "$REPOS" "$REV" "$SENDTO"

AUTHOR=`svnlook author -r $REV $REPOS`
CHANGELOG=`svnlook log -r $REV $REPOS`
echo "INSERT INTO commits (user,url,log) VALUES ('$AUTHOR', '${REPOS##*/}', '${CHANGELOG//\'/''}');" | mysql --login-path=<DB_LOGIN_PATH> svn

$SVNLOOK changed -r "$REV" "$REPOS" | grep -q "trunk/BoardSW/LC"
if [ "$?" -eq "0" ]; then
    $SVNLOOK log -r "$REV" "$REPOS" | grep -q "Jenkins"
    if [ "$?" -eq "0" ]; then
        /usr/bin/wget --quiet -O /dev/null "http://<JENKINS_HOST>/jenkins/job/<JENKINS_JOB>/build?token=<JENKINS_TOKEN>"
    fi
fi
