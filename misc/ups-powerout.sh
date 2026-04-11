#!/bin/sh
# OpenBSD UPS power-out handler.
# Called by the OS when a power failure is detected on a host running OpenBSD
# with a USB/serial UPS presenting as a sensor device (upd0).
#
# Reads the remaining battery runtime from the kernel sensor subsystem,
# converts it from seconds to minutes, logs it, sends an alert email,
# and shuts down if the remaining time is below the threshold.

TimeToShutdown=20

# sysctl returns: hw.sensors.upd0.timedelta0=NNN.NNN secs (battery life)
TimeToDischarge=$(sysctl hw.sensors.upd0.timedelta0)
TimeToDischarge=${TimeToDischarge#*=}    # strip key prefix
TimeToDischarge=${TimeToDischarge%.*}    # strip decimal fraction
TimeToDischarge=$(($TimeToDischarge / 60))  # convert seconds to minutes

logger -t "UpsAlert" "Remaining time on battery is $TimeToDischarge minutes."

echo "Remaining time on battery is $TimeToDischarge minutes." | \
    mail -s "Power Alert on <HOSTNAME>" <ADMIN_EMAIL>

if [ $TimeToDischarge -le $TimeToShutdown ]; then
    echo "Shutdown now!"
    /sbin/shutdown -h +0
else
    echo "There is $(($TimeToDischarge - $TimeToShutdown)) minutes to work on battery."
fi
