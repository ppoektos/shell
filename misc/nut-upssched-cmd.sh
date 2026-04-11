#!/bin/sh
# NUT upssched-cmd handler — called by upssched when a UPS event timer fires.
# Deployed to /etc/nut/upssched-cmd on each host monitored by NUT.
#
# The shutdown delay is configured in upssched.conf (EXECUTE + timer name).
# Different hosts used different grace periods before shutdownnow fires:
#   office1 infrastructure servers: 6 hours
#   office1 edge server:            2 hours
#   office2 server:                 60 minutes

HOSTNAME=$(hostname)

case $1 in
    commbad)
        /bin/echo "UPS communications failure on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS communications LOST [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS communications failure." | /usr/bin/wall
        ;;
    commok)
        /bin/echo "UPS communications restored on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS communications restored [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS communications restored." | /usr/bin/wall
        ;;
    nocomm)
        /bin/echo "UPS communications cannot be established on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS uncontactable [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS communications cannot be established." | /usr/bin/wall
        ;;
    powerout)
        /bin/echo "Power failure on $(date). Orderly shutdown scheduled after grace period." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS on battery [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "Power failure. UPS on battery." | /usr/bin/wall
        ;;
    shutdownnow)
        /bin/echo "UPS battery grace period expired. Starting orderly shutdown on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS on battery — grace period expired, shutdown now [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS grace period expired. Shutting down NOW!!!!" | /usr/bin/wall
        /sbin/shutdown -h +0
        ;;
    shutdowncritical)
        /bin/echo "UPS battery level CRITICAL. Starting EMERGENCY shutdown on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS battery CRITICAL [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS battery level CRITICAL. Shutting down NOW!!!!" | /usr/bin/wall
        /sbin/shutdown -h +0
        ;;
    powerup)
        /bin/echo "Power restored on $(date)." \
            | /usr/bin/mail -a"From:<ROBOT_EMAIL>" \
                -s"UPS on line [$HOSTNAME]" <NOTIFY_EMAIL>
        /bin/echo "UPS on line. Shutdown aborted." | /usr/bin/wall
        ;;
    *)
        /bin/echo "Unrecognized command: $1"
        ;;
esac
