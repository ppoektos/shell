#!/bin/bash
Token=$1
datePrev=0
c=0

case $Token in
    <DEVICE_TOKEN_1>) File=taxi1.txt
    ;;
    <DEVICE_TOKEN_2>) File=taxi2.txt
    ;;
    <DEVICE_TOKEN_3>) File=taxi3.txt
    ;;
    <DEVICE_TOKEN_4>) File=taxi4.txt
    ;;
    <DEVICE_TOKEN_5>) File=taxi5.txt
    ;;
esac

while IFS=, read -r id date longitude latitude; do

    date=$(date -d "$date" +%s)

    dateSleep=$((date - datePrev))

    [[ $c -eq 0 ]] && dateSleep=1

    curl -k -sS -n -X POST -H 'Content-Type: application/json' -d \
    '{"ts":'"${date}000"',
    "values":{
    "longitude":"'$longitude'",
    "latitude":"'$latitude'",
    "voltage": "'13.$((RANDOM%10))'",
    "rpm": "'2$((13 + RANDOM%100))'"
    }}' \
    https://<THINGSBOARD_HOST>/api/v1/$Token/telemetry

    sleep $dateSleep

    datePrev=$date

    ((c++))

done < $File
