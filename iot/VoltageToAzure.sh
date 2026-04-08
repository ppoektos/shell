#!/bin/bash

DEVICE_ID="<AZURE_DEVICE_ID>"
DEVICE_KEY="<AZURE_DEVICE_KEY>"
SCOPE="<AZURE_SCOPE_ID>"


nodejsAuth() {

function getAuth {
  AUTH=`node -e "\
  const crypto   = require('crypto');\

  function computeDrivedSymmetricKey(masterKey, regId) {\
    return crypto.createHmac('SHA256', Buffer.from(masterKey, 'base64'))\
      .update(regId, 'utf8')\
      .digest('base64');\
  }\
  \
  var expires = parseInt((Date.now() + (7200 * 1000)) / 1000);\
  var sr = '${SCOPE}%2f${TARGET}%2f${DEVICE_ID}';\
  var sigNoEncode = computeDrivedSymmetricKey('${DEVICE_KEY}', sr + '\n' + expires);\
  var sigEncoded = encodeURIComponent(sigNoEncode);\
  console.log('SharedAccessSignature sr=' + sr + '&sig=' + sigEncoded + '&se=' + expires)\
  "`
}

SCOPEID="$SCOPE"
TARGET="registrations"
getAuth

OUT=$(curl -s \
  -H "authorization: ${AUTH}&skn=registration" \
  -H 'content-type: application/json; charset=utf-8' \
  -X PUT -d "{\"registrationId\":\"$DEVICE_ID\"}" \
  https://global.azure-devices-provisioning.net/$SCOPEID/registrations/$DEVICE_ID/register?api-version=2018-11-01)

OPERATION=`node -e "c=JSON.parse('$OUT');if(c.errorCode){console.log(c);process.exit(1);}console.log(c.operationId)"`

if [[ $? != 0 ]]; then
  echo "$OPERATION"
  exit
else
  echo "Authenticating.."
  sleep 2

  OUT=$(curl -s \
  -H "authorization: ${AUTH}&skn=registration" \
  -H "content-type: application/json; charset=utf-8" \
  -X GET \
  https://global.azure-devices-provisioning.net/$SCOPEID/registrations/$DEVICE_ID/operations/$OPERATION?api-version=2018-11-01)

  OUT=`node -pe "a=JSON.parse('$OUT');if(a.errorCode){a}else{a.registrationState.assignedHub}"`

  if [[ $OUT =~ 'errorCode' ]]; then
    echo "$OUT"
    exit
  fi

  TARGET="devices"
  SCOPE="$OUT"
  getAuth

  echo "OK"
  echo
fi

}


nodejsAuth


nodejssend () {

  echo "SENDING => " $MESSAGE

  curl -s \
  -H "authorization: ${AUTH}" \
  -H "iothub-to: /devices/$DEVICE_ID/messages/events" \
  --request POST --data "$MESSAGE" "https://$SCOPE/devices/$DEVICE_ID/messages/events/?api-version=2016-11-14"

  echo "DONE"

echo

}


while :; do

    voltage=$(upsc senpro@<UPS_HOST> input.voltage 2>/dev/null)
    temperature=$(upsc senpro@<UPS_HOST> ups.temperature 2>/dev/null)
    runtime=$(upsc senpro@<UPS_HOST> battery.runtime 2>/dev/null | awk '{printf "%.1f\n", $1/3600}')
    status=$(upsc senpro@<UPS_HOST> ups.status 2>/dev/null)

    MESSAGE='{"temperature":"'$temperature'","voltage":"'$voltage'","runtime":"'$runtime'","status":"'$status'"}'

    nodejssend

    sleep 30

done
