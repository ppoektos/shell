#!/bin/bash
BASE_DIR="/mnt/qa"
TMP=$(mktemp)
LOOP=0
LOOPLINK=0
VERSION=`/root/scripts/api.sh version <PAGE_ID>`
NEW_VERSION=`expr $VERSION + 1`

if [ ! -d $BASE_DIR ]
  then
    mkdir /tmp/qa
    mount <QNAP_HOST>:/qa_admin /mnt/qa
fi

cd /tmp
sleep 5
find $BASE_DIR -type d -regextype posix-extended -regex '.*/[[:digit:]x]{8}' | sort -n >$TMP
while read P; do
	E="${P##*/}"
	MAIN="${E::2}"
	SUB="${E:2:2}"
	SERIAL="${E:4}"
	[ "$SERIAL" == "xxxx" ] && SERIAL=
	[ "$SUB" == "xx" ] && SUB=
	DESC_FILE="$P/description.txt"
	DESC=
	if [ -r "$DESC_FILE" ]; then
		DESC=$(sed -rn '1{s/^#+\s*//;s/\s*$//;p};q' "$DESC_FILE")
	fi
	TP=$(mktemp)
	find $P -maxdepth 1 -name "*_released*" > $TP
	LINK=
	while read L; do
		DEST="/usr/share/nginx/html/"
		[ -d "$DEST" ] && cp "$L" "$DEST"
		if [ "$LINK" ]; then
			LINK="$LINK, "
			LOOPLINK=`expr $LOOPLINK + 1`
		fi
		L="${L##*/}"
		if [ $LOOPLINK = "0" ]; then
		LINK="$LINK<a href=\\\"http://<CONFLUENCE_HOST>:81/$L\\\">$L</a>"
		  else
		LINK="$LINK<br><a href=\\\"http://<CONFLUENCE_HOST>:81/$L\\\">$L</a></br>"
		fi
	done <$TP
	LOOPLINK=0
	rm $TP
	REV=
	if [ ! -z "$LINK" ]; then
	  REV=$(echo "$LINK" | sed -rn 's/.*[0-9]{8}([A-Z])_.*/\1/p')
	fi
	if [ -z $SUB ]; then
	    if [ $LOOP = "0" ]; then
		echo -e "<p><b>Main group $MAIN. $DESC</b></p>\n<table>\n<tbody>\n<tr><th>Sub</th><th>Serial</th><th>Rev</th><th>Description</th><th>Files</th></tr>" >> qa2
		LOOP=`expr $LOOP + 1`
	      else
		echo -e "</tbody>\n</table>\n<p><b>Main group $MAIN. $DESC</b></p>\n<table>\n<tbody>\n<tr><th>Sub</th><th>Serial</th><th>Rev</th><th>Description</th><th>Files</th></tr>" >> qa2
	    fi
	  else
	     if [ -z "$SERIAL" -a -z "$REV" ]; then
	      echo "<tr><td><span style=\\\"color: rgb(128,0,0);\\\">$SUB</span></td><td></td><td></td><td><span style=\\\"color: rgb(128,0,0);\\\">$DESC</span></td><td></td></tr>" >> qa2
		else
	      echo "<tr><td></td><td>$SERIAL</td><td>$REV</td><td>$DESC</td><td>$LINK</td></tr>" >> qa2
	     fi
	fi
done < $TMP
sed -i "s/&/&amp;/" qa2
sed -e 's/^.*0001.*Customer registration.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>Customer registration<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/display\/QA\/Customer+number+list\\\">Customer Number List<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*External Typetest Projects.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>External Typetest Projects<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">External Typetest Projects<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*Engineering Change Orders.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>Engineering Change Orders<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">Engineering Change Orders<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*Development Projects.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>Development Projects<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">Development Projects<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*TjeckIt\/PTS Projects.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>TjeckIt projects<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">TjeckIt projects<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*Fabless Projects.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>Fabless Projects<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">Fabless Projects<\/a><\/td><\/tr>/' \
-e 's/^.*0001.*Internal\/Sandbox Projects.*/<tr><td><\/td><td>0001<\/td><td><\/td><td>Internal projects<\/td><td><a href=\\\"http:\/\/<CONFLUENCE_HOST>\/x\/<PAGE_SHORTLINK>\\\">Internal projects<\/a><\/td><\/tr>/' qa2 > qa3
echo -e "</tbody>\n</table>\",\n\"representation\":\"storage\"}},\n\"version\":{\"number\":$NEW_VERSION}}" >> qa3
cat /root/scripts/qa1 qa3 > qa.json
rm $TMP qa2 qa3
/root/scripts/api.sh post qa.json <PAGE_ID>
