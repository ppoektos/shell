# IoT Scripts

Scripts for ThingsBoard and Azure IoT Hub integration. Covers device registration, user provisioning, telemetry ingestion, GPS replay, and UPS monitoring.

## Files

| File | Description |
|------|-------------|
| `DeviceRegistration.sh` | Registers LoRaWAN devices in ThingsBoard, prints device tokens |
| `UsersRegistration.sh` | Batch user registration with admin/user role assignment |
| `cleanTelemetry.sh` | Deletes all telemetry keys for a list of device IDs |
| `iot_bike.sh` | Sends live GPS + telemetry (Speed/Voltage/Distance/Temperature) to ThingsBoard |
| `iot_taxi.sh` | Replays historical CSV taxi GPS data with real timestamps and paced sleep delays |
| `iot_send_data.sh` | Orchestrator — launches multiple `iot_taxi.sh` processes in parallel via nohup |
| `VoltageToAzure.sh` | Reads UPS stats via NUT and sends them to Azure IoT Hub via DPS |
| `VoltageToTBPE.sh` | Reads UPS stats via NUT and sends them to ThingsBoard |

## How it works

### Device and user management

`DeviceRegistration.sh` authenticates to ThingsBoard, iterates a device name list, POSTs each device to the API, then fetches and prints its access token. Supports both cloud and on-premise ThingsBoard (entity group assignment differs).

`UsersRegistration.sh` parses a `FirstName,LastName,email,role` list, looks up the correct group ID per role, and POSTs each user. Activation email is suppressed (`sendActivationMail=false`).

`cleanTelemetry.sh` authenticates and sends a DELETE request per device ID to wipe specific telemetry keys.

### GPS and telemetry simulation

`iot_bike.sh` takes a device token as `$1`. It first walks through a hardcoded GPS coordinate list (2-second intervals), then enters an infinite loop sending random Speed/Voltage/Distance/Temperature values every second until 600 iterations.

`iot_taxi.sh` takes a device token as `$1`, maps it to a historical CSV file, and replays rows with `sleep $dateSleep` — the delay is computed as the difference between consecutive row timestamps in epoch seconds. This reproduces the original timing of real taxi trips.

`iot_send_data.sh` launches one `iot_taxi.sh` instance per device token using `nohup ... &`.

### UPS monitoring

`VoltageToTBPE.sh` polls a UPS via `upsc senpro@<UPS_HOST>` every 15 seconds, maps the `OL` status string to `"ONLINE"` and anything else to `"OFFLINE"`, and sends voltage/temperature/runtime/status to ThingsBoard.

`VoltageToAzure.sh` does the same polling but authenticates to Azure IoT Hub via the Device Provisioning Service (DPS). Authentication uses Node.js inline to compute an HMAC-SHA256 Shared Access Signature — the DPS two-step registration flow (PUT → GET for assigned hub) runs once at startup, then the script loops sending telemetry.

## Notable patterns

**Token-to-file mapping via `case`.** `iot_taxi.sh` maps each device token to its CSV data file with a `case` statement. No external lookup table needed.

**Real-time replay via computed sleep.** `iot_taxi.sh` computes `dateSleep = current_epoch - prev_epoch` from CSV timestamps. The first row always gets `sleep 1` to avoid a zero or negative delay.

**HMAC-SHA256 in bash via Node.js inline.** `VoltageToAzure.sh` embeds a Node.js one-liner inside a bash function using backtick expansion. The script has no Node.js file on disk — the crypto logic lives as a string argument to `node -e`. This lets a shell script perform Azure's required HMAC signing without installing any additional tools.

**DPS two-step provisioning.** Azure IoT Hub requires devices to register via DPS first (PUT), then poll for the assigned hub endpoint (GET), then authenticate against that hub. `VoltageToAzure.sh` handles all three steps inline, reusing the same `getAuth` function with different `TARGET` and `SCOPE` values.

**`nohup` fan-out.** `iot_send_data.sh` is three lines: a token list, a loop, and `nohup ... &`. No process management, no PIDs tracked — each taxi replay runs independently to completion.

**`iot_bike.sh` has unreachable code by design.** The script contains three distinct modes — LoRa payload test, GPS walk, and infinite telemetry loop — separated by `exit` statements. The GPS walk runs and then hits `exit 11`, so the infinite telemetry loop below it never executes. The different exit codes (`exit 22`, `exit 11`) are markers for which mode ran, not error conditions. The script is a development scratchpad with multiple experiments kept in sequence, each gated off by an `exit`.

**`node -pe` vs `node -e` for inline JSON parsing.** `VoltageToAzure.sh` uses `node -pe "..."` in one place — the `-p` flag prints the result of the last expression automatically, so no `console.log()` is needed. This makes JSON field extraction a one-liner: `node -pe "JSON.parse('$OUT').registrationState.assignedHub"`. The `-e` flag elsewhere is for side-effect code that calls `console.log()` itself.

**Derived symmetric key, not a static token.** Azure DPS authentication doesn't use the master device key directly as a bearer token — `VoltageToAzure.sh` derives a per-request HMAC-SHA256 key from the master key, the scope ID, and the device ID concatenated with a newline and an expiry timestamp. The signature changes every request. This is Azure's Shared Access Signature scheme; the Node.js one-liner computes it correctly in 8 lines without any Azure SDK.

**`upsc` status string as a boolean.** `VoltageToTBPE.sh` uses `grep -q OL` to test the UPS status — `OL` is the NUT status code for "On Line" (mains power present). Any other value (OB = On Battery, LB = Low Battery, etc.) maps to `"OFFLINE"`. A single grep replaces what would otherwise be a multi-branch `case` statement over a documented set of NUT status flags.

**`: <<'END' ... END` as a multi-line comment.** `iot_send_data.sh` in its original form uses the null command (`:`) followed by a heredoc to comment out large blocks of code — device creation loops, telemetry deletion calls, bike fan-out — without deleting them. Since `: ` discards all its arguments and the heredoc is just a string, nothing executes. This is the idiomatic bash equivalent of `/* ... */` and preserves the alternative code paths for quick re-enabling.

**On-premise vs cloud ThingsBoard branch.** `DeviceRegistration.sh` checks `if [ $Host = <THINGSBOARD_HOST> ]` to decide whether to append `?entityGroupId=` to the device creation URL. The cloud edition of ThingsBoard uses entity groups for multi-tenancy; the on-premise community edition does not support them and rejects the parameter. One variable switches the entire API shape.
