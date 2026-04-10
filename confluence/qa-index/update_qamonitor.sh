#!/bin/sh
DATE=`date +%d-%m-%Y_%H-%M`

export PAR1=$1
export PAR2=$2

name () {
if [ "${PAR1: -1}" = "/" ]; then
  ITEM="$PAR1$PAR2"
else
  ITEM="$PAR1/$PAR2"
fi
}

case $3 in
  IN_CREATE,IN_ISDIR)
    name
    echo "$DATE. New directory \"$ITEM\" has been added." >> /root/inotify.log
      if [ "$2" != "MISC" -a "$2" != "OLD" ]; then
	echo "$ITEM IN_CLOSE_WRITE,IN_CREATE,IN_DELETE /root/update_qamonitor.sh \$@ \$# $%" >> /etc/config/incron.d/qamonit.conf
	/etc/init.d/incron.sh restart
	sleep 3
	UPDATE="0"
      fi
  ;;
  IN_DELETE,IN_ISDIR)
    name
    echo "$DATE. Directory \"$ITEM\" has been removed." >> /root/inotify.log
      if [ "$2" != "MISC" -a "$2" != "OLD" ]; then
	M=$(echo "$ITEM" | sed 's/\//\\\//g')
	sed -i "/$M/d" /etc/config/incron.d/qamonit.conf
	/etc/init.d/incron.sh restart
	sleep 3
	UPDATE="0"
      fi
  ;;
  IN_CLOSE_WRITE)
    name
    echo "$DATE. New file \"$ITEM\" has been added." >> /root/inotify.log
    echo "$2" | grep -q ".*_released.*" && UPDATE="1"
  ;;
  IN_DELETE)
    name
    echo "$DATE. File \"$ITEM\" has been removed." >> /root/inotify.log
    echo "$2" | grep -q ".*_released.*" && UPDATE="1"
  ;;
  *) echo "`basename $0`: nothing to do." && exit 1
  ;;
esac

if [ "$UPDATE" -eq "1" ]; then
    ssh root@<CONFLUENCE_HOST> '/root/scripts/qa.sh'
  else
    exit 1
fi
