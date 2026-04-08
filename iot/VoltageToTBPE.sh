#!/bin/bash

Token=<DEVICE_TOKEN>

while :; do

    voltage=$(upsc senpro@<UPS_HOST> input.voltage 2>/dev/null)
    temperature=$(upsc senpro@<UPS_HOST> ups.temperature 2>/dev/null)
    runtime=$(upsc senpro@<UPS_HOST> battery.runtime 2>/dev/null | awk '{printf "%.1f\n", $1/3600}')
    status=$(upsc senpro@<UPS_HOST> ups.status 2>/dev/null)

    if echo $status | grep -q OL; then
        status="ONLINE"
        else
        status="OFFLINE"
    fi

    curl -sS -n -X POST -H 'Content-Type: application/json' -d \
    '{"voltage":'"$voltage"',
    "temperature":'"$temperature"',
    "runtime":'"$runtime"',
    "status":'"$status"'
     }' \
    https://<THINGSBOARD_HOST>/api/v1/$Token/telemetry

    sleep 15

done
