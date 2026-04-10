#!/bin/bash
cd /tmp
rm -f svn.*w
cp -f /root/top.*w .

SWDE="('user1', 'user2', 'user3', 'user4', 'user5', 'user6', 'user7')"
HWDE="('user8', 'user9', 'user10', 'user11', 'user12', 'user13', 'user14', 'user15', 'user16')"

mysql --login-path=<DB_LOGIN_PATH> -N -e "use svn; \
SELECT * \
FROM commits \
WHERE user IN $SWDE \
AND date >= CURDATE() \
ORDER BY user;" | while IFS=$'\t' read id date user url log; do
echo "<tr><td>$id</td><td>$date</td><td>$user</td><td>$url</td><td>$log</td></tr>" >> svn.sw
sed -i "s/ ${user},//" top.sw
done

sed -i "s/,</.</" top.sw

if [ -f svn.sw ]; then
    cat top.sw svn.sw /root/bottom > svnsw.html
    else
    cat top.sw /root/bottom > svnsw.html
fi

mutt -e 'set content_type="text/html"' -s "Svn SW daily report" -- <SW_LEAD_EMAIL> < svnsw.html

sleep 10

mysql --login-path=<DB_LOGIN_PATH> -N -e "use svn; \
SELECT * \
FROM commits \
WHERE user IN $HWDE \
AND date >= CURDATE() \
ORDER BY user;" | while IFS=$'\t' read id date user url log; do
echo "<tr><td>$id</td><td>$date</td><td>$user</td><td>$url</td><td>$log</td></tr>" >> svn.hw
sed -i "s/ ${user},//" top.hw
done
sed -i "s/,</.</" top.hw
cat top.hw svn.hw > svnhw.html 2>/dev/null

mysql --login-path=<DB_LOGIN_PATH> -N -s -e "use svn; \
SELECT COUNT(*) \
FROM commits \
WHERE url LIKE '%bom%' \
AND date >= CURDATE();" | while read answer; do
if [ "$answer" -eq "0" ]; then
echo -e "</table><br>\nUnfortunately developers were so lazy today to commit into bom-cost-calculation-tool.\n</body>\n</html>" >> svnhw.html
else
echo -e "</table>\n<p>Commits to bom-cost-calculation-tool.</p><br>\n<table border=\"1\">\n<tr><td>Date</td><td>User</td><td>Comment</td></tr>" >> svnhw.html
mysql --login-path=<DB_LOGIN_PATH> -N -e "use svn; \
SELECT * \
FROM commits \
WHERE url LIKE '%bom%' \
AND date >= CURDATE() \
ORDER BY user;" | while IFS=$'\t' read date user log; do
echo "<tr><td>$date</td><td>$user</td><td>$log</td></tr>" >> svnhw.html
done
echo -e "</table>\n</body>\n</html>" >> svnhw.html
fi
done

mutt -e 'set content_type="text/html"' -s "Svn HW daily report" -- <HW_LEAD_EMAIL> < svnhw.html
