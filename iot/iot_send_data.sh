#!/bin/bash
DeviceTokens="<DEVICE_TOKEN_1>
              <DEVICE_TOKEN_2>
              <DEVICE_TOKEN_3>
              <DEVICE_TOKEN_4>
              <DEVICE_TOKEN_5>"

for Token in $DeviceTokens; do
    nohup ./iot_taxi.sh $Token &
done
