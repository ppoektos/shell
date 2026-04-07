# ISP Failover

Automatic dual-WAN switchover for OpenBSD gateways. Monitors internet
connectivity and switches between two ISPs when the primary fails, including
firewall and IPSec tunnel reload. Comes with a web UI to manually control
the daemon.

## Files

| File | Description |
|------|-------------|
| `check_internet.sh` | Failover daemon — monitors connectivity, switches ISPs |
| `wrapper.sh` | Service manager — start/stop/check the daemon |
| `backupInternet.php` | Web UI — remotely control wrapper.sh via browser |

## How it works

`check_internet.sh` runs as a background daemon. Every cycle it tests
connectivity on the current ISP using both ping and wget — both must fail
before switching (avoids false positives from transient packet loss).

On switch it:
1. Changes the default route
2. Reloads PF firewall with the correct ISP config
3. Reloads IPSec tunnels for the new ISP endpoints
4. Triggers IPSec reload on a remote server via SSH
5. Sends an email notification

When on Provider2 (backup), it additionally tests if Provider1 has recovered
each cycle and switches back automatically.

Polling interval is 60s on Provider1, 30s on Provider2 (faster restoration check).

`wrapper.sh` manages the daemon lifecycle using a PID file and nohup.

`backupInternet.php` is a minimal web page hosted on an internal server. It
SSHs into the gateway and calls `wrapper.sh start/stop/check` — useful when
the internet is down and you need to interact with the daemon from inside
the LAN without terminal access.

