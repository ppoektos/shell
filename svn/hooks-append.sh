#!/bin/sh
# Retrofits the DB INSERT statement to every existing post-commit hook.
# Used when the mysql logging line was added to the template after repos
# were already deployed — appends it to all hooks in one pass.
# Run from the SVN repositories root directory (e.g. /mnt/svn).

DIRS=`find . -type d -name "hooks"`

for f in $DIRS
do
    if [ -f $f/post-commit ]
      then
        echo  "

AUTHOR=\`svnlook author -r \$REV \$REPOS\`
CHANGELOG=\`svnlook log -r \$REV \$REPOS\`
echo \"INSERT INTO commits (user,url,log) VALUES ('\$AUTHOR', '\${REPOS##*/}', '\${CHANGELOG//\\'/''}');\" | mysql --login-path=<DB_LOGIN_PATH> svn" >> $f/post-commit
    fi
done
