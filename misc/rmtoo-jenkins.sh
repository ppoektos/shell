#!/bin/bash
# Jenkins build script for rmtoo requirements processing.
# Triggered by an SVN post-commit hook on the rmtoo repository.
# Determines which requirement files changed in the triggering revision,
# copies them into the rmtoo build directory, runs make, and exports
# the resulting PDF and PNG artifacts back to the workspace.
# The committing engineer's username (derived from the SVN path) is written
# to rmtoo.properties so a downstream Jenkins job can email them the output.

# workdir
wd="/home/jenkins/workspace/Test_projects_and_templates/rmtoo"
chown -R jenkins "$wd"
cd "$wd"
# builddir
bd="/opt/RMTOO/TestProject1"

rm -f $bd/requirements/*.*
rm -f $wd/*.pdf
rm -f $wd/*.png
rm -f $bd/artifacts/*.pdf
rm -f $bd/artifacts/*.png

Rev=$(svn info | grep Revision | grep -o '[[:digit:]]*')
echo "Revision is $Rev."

files=$(ssh root@<SCM_HOST> "svnlook changed -r $Rev /mnt/svn/rmtoo" \
        | grep -E 'U|A' | grep input | awk '{print $2}')
echo "Files are $files."

for f in $files; do
    echo "File is $f."
    user=$(echo $f | awk -F/ '{print $1}')
    echo "User is $user."
    cp -f "$f" ${bd}/requirements/
done

cd $bd
source ./setenv.sh DEB
make
cp -f artifacts/requirements.pdf "$wd"/$user/output/
cp -f artifacts/requirements.pdf "$wd"
cp -f artifacts/*.png "$wd"

cd "$wd"
echo "rcpt=${user}@<DOMAIN>" > rmtoo.properties

exit 0
