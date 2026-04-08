#!/bin/sh
/usr/bin/ssh root@lic.$1 'echo "Hostname is `hostname`."; \
date; \
echo "Stopping daemon.."; echo; \
yes | /etc/init.d/lmgrd stop; echo; \
echo "Waiting one minutes to safely stop lmgrd."; \
sleep 61; \
echo "Starting daemon.."; \
/etc/init.d/lmgrd start; \
sleep 30; \
echo "Daemon has been started. Current status is:"; echo; \
/opt/flexlm/lmstat -a -c /opt/license.dat'
