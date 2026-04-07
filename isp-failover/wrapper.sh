#!/bin/ksh

pid=/var/run/checkInet.pid

stop_f () {

if [ -f "$pid" ]; then
    kill -6 $(cat $pid) && echo Stopped
    else
    echo "Script isn't running, nothing to stop."
fi

}

check_f () {

if pgrep -f check_internet; then
    echo "Script is already running"
    tail /home/nohup.out
    return 0
    else
    echo "Script isn't running"
    return 1
fi

}

start_f () {

if check_f; then return; fi

sleep 1
cd /home
nohup ./check_internet > nohup.out 2> nohup.out < /dev/null &
echo Started

}

case $1 in
    check)  check_f
    ;;
    start)  start_f && exit
    ;;
    stop)   stop_f
    ;;
esac
