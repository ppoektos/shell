#!/bin/bash
AuthURL=https://<THINGSBOARD_HOST>/api/auth/login
CustomerAdmin=<TB_USERNAME>
CustomerPassword=<TB_PASSWORD>

DeviceIDs="<DEVICE_ID_1>
           <DEVICE_ID_2>
           <DEVICE_ID_3>
           <DEVICE_ID_4>
           <DEVICE_ID_5>"

Token=$(curl -sS -n -X POST \
        -H 'Content-Type:application/json' \
        -H 'Accept:application/json' \
        -d '{"username":"'$CustomerAdmin'","password":"'$CustomerPassword'"}' \
        $AuthURL | python -mjson.tool | grep token | awk -F\" '{print $4}')

for ID in $DeviceIDs; do

curl -sS -n -X DELETE -H 'Accept: text/html' \
-H 'X-Authorization: Bearer '$Token'' \
"https://<THINGSBOARD_HOST>/api/plugins/telemetry/DEVICE/$ID/timeseries/delete?keys=longitude%2Clatitude%2Crpm%2Cvoltage&deleteAllDataForKeys=true&rewriteLatestIfDeleted=false"

done

echo
