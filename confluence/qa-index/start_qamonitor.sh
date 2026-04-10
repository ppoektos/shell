#!/bin/sh
# Usage:
# /opt/bin/find /share/qa_admin/ -type d -not -path "*MISC" -not -path "*OLD" -exec /root/start_qamonitor.sh {} \;
# Then:
# /etc/init.d/incron.sh restart
echo "$1 IN_CLOSE_WRITE,IN_CREATE,IN_DELETE /root/update_qamonitor.sh \$@ \$# $%" >> /etc/config/incron.d/qamonit.conf
