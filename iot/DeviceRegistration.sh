#!/bin/bash
Host=<THINGSBOARD_HOST>

AuthURL=https://$Host/api/auth/login
AddDeviceURL=https://$Host/api/device

entityGroupId=<ENTITY_GROUP_ID>

CustomerAdmin=<TB_USERNAME>
CustomerPassword=<TB_PASSWORD>

DeviceList="LORAWAN-DEVICE-1
            LORAWAN-DEVICE-2
            LORAWAN-DEVICE-3"

Token=$(curl -sS -n -X POST \
        -H 'Content-Type:application/json' \
        -H 'Accept:application/json' \
        -d '{"username":"'$CustomerAdmin'","password":"'$CustomerPassword'"}' \
        $AuthURL \
    | python -mjson.tool | grep token | awk -F\" '{print $4}')


if [ $Host = <THINGSBOARD_HOST> ]; then
    PostAddDeviceURL=$AddDeviceURL
    else
    PostAddDeviceURL=$AddDeviceURL?entityGroupId=$entityGroupId
fi


for Device in $DeviceList; do

    DeviceID=$(curl -sS -n -X POST \
            -H 'Content-Type:application/json' \
            -H 'Accept:application/json' \
            -H 'X-Authorization: Bearer '$Token'' \
            -d '{"name": "'$Device'", "type": "lorawan-type" }' \
            $PostAddDeviceURL \
        | python -mjson.tool | grep -A 1 DEVICE | grep id | awk -F\" '{print $4}')

    DeviceToken=$(curl -sS -n -X GET \
                -H 'Accept: application/json' \
                -H 'X-Authorization: Bearer '$Token'' \
                $AddDeviceURL/$DeviceID/credentials \
        | python -mjson.tool | grep credentialsId | awk -F\" '{print $4}')

    echo "Device name: $Device."
    echo "Device ID: $DeviceID."
    echo "Device token: $DeviceToken."
    echo -----------------------------

done
