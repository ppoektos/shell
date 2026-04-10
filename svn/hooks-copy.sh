#!/bin/sh
# Deploys post-commit and pre-commit to every repo hooks/ dir that is missing them.
# Run from the SVN repositories root directory (e.g. /mnt/svn).

DIRS=`find . -type d -name "hooks"`

for f in $DIRS
do
    if [ -f $f/post-commit ]
      then
        :
      else
        echo "$f does not have post-commit file."
        echo "Copying.."
        cp -p ./{post-commit,pre-commit} $f
        echo "Done."
    fi
done
