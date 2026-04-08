#!/bin/bash
counter=0
Distance=0
Token=$1

GPS="50.046359 36.284868
     50.046343 36.285198
     50.046321 36.285659
     50.046025 36.285833
     50.046462 36.288043
     50.046505 36.289451
     50.050535 36.289075"

while read -r latitude longitude; do

    echo Long: $longitude
    echo Lat: $latitude

    curl -sS -n -X POST -H 'Content-Type: application/json' -d \
    '{
    "longitude": '$longitude',
    "latitude": '$latitude'
    }' \
    https://<THINGSBOARD_HOST>/api/v1/$Token/telemetry

    sleep 2

done <<< "$GPS"

while :; do

    curl -sS -n -X POST -H 'Content-Type: application/json' -d \
    '{
    "Speed": '$((20 + RANDOM%4))',
    "Voltage": '$((13 + RANDOM%3))',
    "Distance": '$Distance',
    "Temperature": '$((50 + RANDOM%2))'
    }' \
    https://<THINGSBOARD_HOST>/api/v1/$Token/telemetry

    ((counter++))

    Distance=$((Distance + RANDOM%3))

    [[ $counter -gt 600 ]] && exit 0

    sleep 1

done
