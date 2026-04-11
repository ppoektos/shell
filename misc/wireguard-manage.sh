#!/usr/bin/env bash
#
# This scripts does not set up filter/nat rules.
#

# Constants
WORK_DIR="/etc/wireguard"

# TBD in process
declare COLORS
declare SERV_CONF_DIR
declare SERV_CONF
declare SUBNET
declare SERV_EIP
declare PUB_KEY_SERV
declare PSK_KEY
declare CLIENT_NAME
declare CLIENT_CONF
declare CLIENT_AIPS
declare CHECK_OLD
declare IS_SLACKWARE=0
declare -ar PKG_LIST=( "wireguard" "wireguard-tools" "resolvconf" "qrencode" )

check_root() {
  if ((EUID != 0)); then
    echo "Run as root"
    exit 1
  fi
}

pm_check() {
  ##################################################
  # Check for package managers
  ##################################################

  if ! command -v apt >/dev/null 2>&1; then
    if ! command -v dnf >/dev/null 2>&1; then
      if command -v slackpkg >/dev/null 2>&1; then
        IS_SLACKWARE=1
      else
        echo "Supported package managers are not available."
        echo "Install next packages manually:
${PKG_LIST[@]}"
        exit 1
      fi
    fi
  fi
}

install_pkgs() {
  ##################################################
  # Install necessary packages
  ##################################################

  to_install=()
  for pkg in "${PKG_LIST[@]}"; do
    if command -v apt >/dev/null 2>&1; then
      if ! dpkg -l | awk '{print $2}'| grep -E "^\\$pkg$" >/dev/null 2>&1; then
        to_install+=( "$pkg" )
      fi
      to_install_len="${#to_install[@]}"
      if ((to_install_len > 0)); then
        apt update
        apt install "${to_install[@]}" -y
      fi
    elif command -v dnf >/dev/null 2>&1; then
      if ! dnf list "$pkg" >/dev/null 2>&1; then
        to_install+=( "$pkg" )
      fi
      if ((to_install_len > 0)); then
        dnf install "${to_install[@]}" -y
      fi
    elif command -v slackpkg >/dev/null 2>&1; then
      if ! find /var/lib/pkgtools/packages | grep -q "$pkg"; then
        to_install+=( "$pkg" )
      fi
      if ((to_install_len > 0)); then
        slackpkg install "${to_install[@]}"
      fi      
    fi
  done

  echo "All dependencies are satisfied."
}

serv_exist_check() {
  ##################################################
  # Check if server exists
  ##################################################

  wg_configs_num="$(find "$WORK_DIR" -maxdepth 1 -type f -name "wgmy*.conf" 2>/dev/null | wc -l)"
  if ((wg_configs_num == 1)); then
    if ! command -v wg-quick >/dev/null 2>&1; then
      pm_check
      install_pkgs
    fi
    SERV_CONF="$(find "$WORK_DIR" -maxdepth 1 -type f -name "wgmy*.conf")"
    CHECK_OLD=1
    show_menu
  elif ((wg_configs_num > 1)); then
    counter=1
    used_ifaces=()
    echo "Choose server:"
    while read -r used_iface; do
      used_ifaces[$counter]="$used_iface"
      echo "${counter}. $(basename "${used_iface%%.conf}")"
      counter=$((counter+1))
    done < <(find "$WORK_DIR" -maxdepth 1 -type f -name "wgmy*.conf")
    echo "${counter}. Set up new server."
    read -e -p ":> " -r answer_serv
    if ! [[ "0123456789" =~ $answer_serv ]]; then
      echo "Wrong characters. Try again."
      serv_exist_check
      return
    fi
    if ((answer_serv < 1)) || ((answer_serv > counter)); then
      echo "Wrong number. Try again."
      serv_exist_check
      return
    fi
    CHECK_OLD=1
    case "$answer_serv" in
      "$counter" ) pm_check
                   install_pkgs
                   setup_new_server
                   ;;
      * ) SERV_CONF="${used_ifaces[$answer_serv]}"
          show_menu
          ;;
    esac
  else
    echo "Set up new wireguard server? [y/n]"
    read -e -p ":> " -r answer_install
    case "$answer_install" in
      y|Y ) pm_check
            install_pkgs
            CHECK_OLD=0
            setup_new_server
            ;;
      * ) echo "Exiting..."
          exit 0
          ;;
    esac
  fi
}

show_menu() {
  ##################################################
  # Show server menu
  ##################################################

  name="$(basename "$SERV_CONF")"
  SERV_CONF_DIR="${WORK_DIR}/.${name%%.conf}-configs"
  PUB_KEY_SERV="$(cat "${SERV_CONF_DIR}/serv.pub")"
  PSK_KEY="$(cat "${SERV_CONF_DIR}/serv.psk")"
  SUBNET="$(awk -F: '/^# SUB/ {print $NF}' "$SERV_CONF")"
  SERV_EIP="$(awk -F: '/^# EIP/ {print $(NF-1)}' "$SERV_CONF")"
  PORT="$(awk -F: '/^# EIP/ {print $NF}' "$SERV_CONF")"
  if command -v slackpkg >/dev/null 2&>1; then
    IS_SLACKWARE=1
  fi

  # What to do
  echo "Interface: ${name%%.conf}"
  echo "1. Add new client."
  echo "2. List clients."
  echo "3. Remove client."
  echo "4. Regenerate QR code."
  echo "5. Remove server."
  echo "6. Set up new server."
  read -e -p ":> " -r answer_todo

  case "$answer_todo" in
    1 ) add_new_client
        ;;
    2 ) list_clients
        ;;
    3 ) remove_client
        ;;
    4 ) regenerate_qr
        ;;
    5 ) remove_server
        ;;
    6 ) setup_new_server
        ;;
    * ) echo "Wrong choise. Try again."
        show_menu
        return
        ;;
  esac
}

set_serv_subnet() {
  ##################################################
  # Set new server subnet
  ##################################################

  used_subs=()
  if ((CHECK_OLD == 1)); then
    while read -r conf; do
      used_sub="$(awk -F: '/^# SUB/ {print $NF}' "$conf")"
      used_subs+=( "$used_sub" )
    done < <(find "$WORK_DIR" -maxdepth 1 -type f -name 'wgmy*.conf')
  fi
  while read -r sys_sub; do
    if ! [[ ${used_subs[*]} =~ $sys_sub ]]; then
      used_subs+=( "$sys_sub" )
    fi
  done < <(ip a | awk '/inet / {print $2}' | grep -v '127.0.*' | sed -r 's/\.[0-9]{1,3}\/[0-9]{1,2}//')
  echo "Set wireguard subnet (format 10.x.x)."
  echo "Allowed subnets: 10/8 (10.0.0-10.255.255)."
  echo "Reserved subnets: ${used_subs[*]:-none}"
  if ! [[ ${used_subs[*]} =~ "10.70.71" ]]; then
    read -e -p ":> " -i "10.70.71" -r answer_subnet
  else
    read -e -p ":> " -r answer_subnet
  fi
  if ! [[ $answer_subnet =~ ^10\.[0-9][0-9]*[0-9]*\.[0-9][0-9]*[0-9]*$ ]]; then
    echo "Subnet $answer_subnet is out of range/reserved/wrong. Try another one."
    unset used_subs
    set_serv_subnet
    return
  elif [[ ${used_subs[*]} =~ $answer_subnet ]]; then
    echo "Subnet $answer_subnet is out of range/reserved/wrong. Try another one."
    unset used_subs
    set_serv_subnet
    return
  fi
  SUBNET="$answer_subnet"
}

set_serv_port() {
  ##################################################
  # Set new server port
  ##################################################

  used_ports=()
  if ((CHECK_OLD == 1)); then
    while read -r conf; do
      used_port="$(awk -F: '/^# EIP/ {print $NF}' "$conf")"
      used_ports+=( "$used_port" )
    done < <(find "$WORK_DIR" -maxdepth 1 -type f -name 'wgmy*.conf')
  fi
  while read -r sys_port; do
    if ((sys_port >= 49152)) && ! [[ ${used_ports[*]} =~ $sys_port ]]; then
      used_ports+=( "$sys_port" )
    fi
  done < <(ss -tulwnH | awk '{print $5}' | grep -v '^ *$' | awk -F: '{print $NF}' | sort -hu)
  echo "Set wireguard server port."
  echo "Allowed range: 49152-65535."
  echo "Reserved ports: ${used_ports[*]:-none}"
  for ((suggested_port=49152;suggested_port<=65535;suggested_port++)); do
    if ! [[ ${used_ports[*]} =~ $suggested_port ]]; then
      break
    fi
  done
  read -e -p ":> " -i "$suggested_port" -r answer_port
  if ((answer_port < 49152)) || ((answer_port > 65535)) || [[ ${used_ports[*]} =~ $answer_port ]]; then
    echo "Port $answer_port is out of range/reserved/wrong. Try another one."
    unset used_ports
    set_serv_port
    return
  fi
  PORT="$answer_port"
}

set_serv_eip() {
  ##################################################
  # Set new server ip
  ##################################################

  counter=1
  ips=()
  echo "Set server external IP to access wireguard server."
  while read -r ip; do
    ips[$counter]="$ip"
    echo "${counter}. ${ips[$counter]}"
    counter=$((counter+1))
  done < <(hostname -I | sed 's/ $//; s/ /\n/g')
  echo "${counter}. Custom."
  read -e -p ":> " -r answer_ip
  if ! [[ "0123456789" =~ $answer_ip ]]; then
    echo "Wrong characters. Try again."
    serv_exist_check
    return
  fi
  if [[ $answer_ip -lt 1 || $answer_ip -gt $counter ]]; then
    echo "Wrong number. Try again."
    set_serv_eip
  elif ((answer_ip == counter)); then
    echo "Set custom ip"
    read -e -p ":> " -r custom_ip
    SERV_EIP="$custom_ip"
  else
    SERV_EIP="${ips[$answer_ip]}"
  fi
}

setup_new_server() {
  ##################################################
  # Create new server
  ##################################################

  used_ifaces=()
  for used_iface in "$WORK_DIR"/wgmy*.conf; do
    used_ifaces+=( "$(basename "$used_iface")" )
  done
  for sys_iface in $(ip link show | awk '/^[0-9]+:/ {gsub(/:/, "", $2); print $2}'); do
    if ! [[ ${used_ifaces[*]} =~ $sys_iface ]]; then
      used_ifaces+=( "$sys_iface" )
    fi
  done
  for ((c=0;c<=65535;c++)); do
    if ! [[ ${used_ifaces[*]} =~ wgmy${c}.conf ]]; then
      SERV_CONF="$WORK_DIR"/wgmy${c}.conf
      SERV_CONF_DIR="$WORK_DIR"/.wgmy${c}-configs
      break
    else
      continue
    fi
  done

  prv_key_serv_path="${SERV_CONF_DIR}/serv.prv"
  pub_key_serv_path="${SERV_CONF_DIR}/serv.pub"
  psk_key_path="${SERV_CONF_DIR}/serv.psk"
  umask 177
  mkdir -p "$SERV_CONF_DIR"
  wg genkey | tee "$prv_key_serv_path" | wg pubkey > "$pub_key_serv_path"
  wg genpsk > "$psk_key_path"
  PSK_KEY="$(cat "$psk_key_path")"
  PUB_KEY_SERV="$(cat "$pub_key_serv_path")"
  prv_key_serv="$(cat "$prv_key_serv_path")"

  set_serv_subnet
  set_serv_port
  set_serv_eip
  serv_iip=${SUBNET}.1

  umask 177
  cat >> "$SERV_CONF" <<EOF
# SERVER
# EIP:${SERV_EIP}:${PORT}
# SUB:$SUBNET
[Interface]
Address = $serv_iip
PrivateKey = $prv_key_serv
ListenPort = $PORT

# PEERS
EOF

  # Enable forwarding
  is_enabled_forwarding="$(sysctl net.ipv4.ip_forward | awk -F " = " '{print $NF}')"
  if ((is_enabled_forwarding != 1)); then
    cat >> /etc/sysctl.d/99-wireguard-forward.conf <<EOF
net.ipv4.ip_forward=1
EOF
    sysctl -p /etc/sysctl.d/77-wireguard-forward.conf
  fi

  add_new_client
  start_server
}

add_new_client() {
  ##################################################
  # Add new client
  ##################################################

  # Get new client name
  echo "New client name"
  echo "Allowed characters: a-Z0-9-_"
  echo "No more than 14 chars."
  read -e -p ":> " -r -n 14 cliname
  case "$cliname" in
    *[!abcdefghijklmnopqrstuvwzyx0123456789\-_]* ) echo "Forbidden characters. Try again."
                                                   add_new_client
                                                   return
                                                   ;;
  esac
  iface_name="$(basename "${SERV_CONF%%.conf}")"
  CLIENT_NAME="${iface_name}-${cliname}"
  CLIENT_CONF="${SERV_CONF_DIR}/${CLIENT_NAME}.conf"
  if [[ -f "$CLIENT_CONF" ]]; then
    echo "Client $CLIENT_NAME exists. Try again with another name."
    add_new_client
    return
  fi

  set_cli_aips

  # Set new client address
  if ! grep "AllowedIPs *= *${SUBNET}.2" "$SERV_CONF" >/dev/null 2>&1; then
    client_iip=${SUBNET}.2
  else
    readarray iips_arr <<< "$(grep "AllowedIPs *= *" "$SERV_CONF" \
      | grep -Eo "${SUBNET}\.[1-9]{1,3}" \
      | sort -u)"
    for ((c=2;c<=65535;c++)); do
      if ! [[ ${iips_arr[*]} =~ ${SUBNET}.$c ]]; then
        client_iip=${SUBNET}.$c
        break
      else
        continue
      fi
    done
  fi

  # Create new client
  tmp_dir="$(mktemp -dq)"
  prv_key_cli_path="${tmp_dir}/${CLIENT_NAME}.prv"
  pub_key_cli_path="${tmp_dir}/${CLIENT_NAME}.pub"
  umask 077
  wg genkey | tee "$prv_key_cli_path" | wg pubkey > "$pub_key_cli_path"
  pub_key_cli="$(cat "$pub_key_cli_path")"
  prv_key_cli="$(cat "$prv_key_cli_path")"

  cat >> "$CLIENT_CONF" <<EOF
[Interface]
Address = $client_iip/24
PrivateKey = $prv_key_cli
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $PUB_KEY_SERV
PresharedKey = $PSK_KEY
AllowedIPs = $CLIENT_AIPS
Endpoint = ${SERV_EIP}:${PORT}
PersistentKeepalive = 10
EOF

  echo "$CLIENT_CONF has been created."

  # Add client info to server
  cat >> "$SERV_CONF" <<EOF
# BEGIN PEER:${CLIENT_NAME}
[Peer]
PublicKey = $pub_key_cli
PresharedKey = $PSK_KEY
AllowedIPs = $client_iip/32
# END PEER:$CLIENT_NAME
EOF
  echo "$SERV_CONF has been updated."
  generate_qr "$CLIENT_CONF"
  rm -rf "$tmp_dir"
}

generate_qr() {
  ##################################################
  # Regenerate QR for specified client
  ##################################################

  qrencode -t UTF8 < "$1"
}

start_server() {
  ##################################################
  # Start server on demand
  ##################################################

  iface_name="$(basename "${SERV_CONF%%.conf}")"
  echo "Enable and start $iface_name now? [y/n]"
  read -e -p ":> " -r to_start
  case "$to_start" in
    y | Y )
      if ((IS_SLACKWARE == 0)); then
        # Systemd way
        systemctl enable --now wg-quick@"$iface_name".service
      elif ((IS_SLACKWARE == 1)); then
        # Slackware way
        echo "$(which wg-quick) up $iface_name" >> /etc/rc.d/rc.local
        wg-quick up "$iface_name"
      fi
      return
      ;;
    n | N )
      echo "Server is off. Exiting."
      exit 0
      ;;
    * )
      echo "Wrong answer. Try again."
      start_server
      return
      ;;
  esac
}

set_cli_aips() {
  ##################################################
  # Set client AllowedIPs
  ##################################################

  echo "Allowed IPs for $CLIENT_NAME:"
  echo "1. Any."
  echo "2. Only vpn clients."
  echo "3. Custom."
  read -e -p ":> " -r answer_allowed_ips

  case "$answer_allowed_ips" in
    1 ) CLIENT_AIPS="::/0, 0.0.0.0/0"
        ;;
    2 ) CLIENT_AIPS="${SUBNET}.0/24"
        ;;
    3 ) echo "Enter allowed IPs. Separate each ip or subnet with single space."
        echo "Like 184.30.0.0/24 1.1.1.1 91.15.0.0/16"
        read -e -p ":> " -r -a allowed_ips
        for IP in "${allowed_ips[@]}"; do
          if ! [[ $IP =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))(/[0-9]{1,2})*$ ]]; then
            echo "$IP in not a valid ip or subnet."
            set_cli_aips
            return
          fi
        done
        CLIENT_AIPS="$(echo "${allowed_ips[*]}" | sed 's/ /, /g')"
        ;;
    * ) echo "Wrong answer. Choose 1 or 2."
        set_cli_aips
        return
        ;;
  esac
}

remove_client() {
  ##################################################
  # Remove client
  ##################################################

  echo "Which client you want to delete?"
  counter=1
  peers=()
  while read -r peer; do
    peers[$counter]="$peer"
    echo "${counter}. ${peers[$counter]}"
    counter=$((counter+1))
  done < <(awk -F: '/^# BEGIN PEER/ {print $NF}' "$SERV_CONF")
  read -e -p ":> " -r answer_delete
  if ! [[ "0123456789" =~ $answer_delete ]]; then
    echo "Wrong characters. Try again."
    serv_exist_check
    return
  fi
  if ((answer_delete >= 1)) && ((answer_delete < counter)); then
    peer_to_delete="${peers[$answer_delete]}"
    echo "Delete ${peer_to_delete}? Type YES to delete."
    read -e -p ":> " -r answer_delete
    case "$answer_delete" in
      YES )
        sed -i.backup "/^# BEGIN.*\\$peer_to_delete$/,/^# END.*\\$peer_to_delete$/d" "$SERV_CONF"
        rm -vf "${SERV_CONF_DIR}/${peer_to_delete}.conf"
        echo "Peer $peer_to_delete has been deleted."
        ;;
      * )
        echo "Peer $peer_to_delete was NOT deleted."
        echo "Exiting..."
        return
        ;;
    esac
  else
    echo "Wrong number. Try again."
    remove_client
    return
  fi
}

list_clients() {
  ##################################################
  # List all clients
  ##################################################

  echo "$(basename "${SERV_CONF%%.conf}") clients:"
  counter=1
  if ! grep "^# BEGIN PEER" "$SERV_CONF" >/dev/null 2>&1; then
    echo "No clients."
    return
  fi
  printf "%3s %-20s %-12s %-s\n" "# " "Client" "IP" "Allowed IPs"
  while read -r peer; do
    peer_ip="$(awk -F " = " '/^Address/ {gsub(/\/../,"",$NF); print $NF}' "${SERV_CONF_DIR}/${peer}.conf")"
    peer_allowed="$(awk -F " = " '/^AllowedIPs/ {gsub(/\, /, "|", $NF); print $NF}' "${SERV_CONF_DIR}/${peer}.conf")"
    echo "${counter}. $peer $peer_ip $peer_allowed"
    counter=$((counter+1))
  done < <(awk -F: '/^# BEGIN PEER/ {print $NF}' "$SERV_CONF") | xargs printf "%3s %-20s %-12s %s\n"
}

regenerate_qr() {
  ##################################################
  # Regenerate QR for specified client
  ##################################################

  if ! grep -q "^# BEGIN PEER" "$SERV_CONF"; then
    echo "No clients."
    return
  fi
  echo "Choose client to regenerate QR code."
  counter=1
  peers=()
  while read -r peer; do
    peers[$counter]="$peer"
    echo "${counter}. ${peers[$counter]}"
    counter=$((counter+1))
  done < <(awk -F: '/^# BEGIN PEER/ {print $NF}' "$SERV_CONF")
  read -e -p ":> " -r answer_regenerate
  if ! [[ "0123456789" =~ $answer_regenerate ]]; then
    echo "Wrong characters. Try again."
    serv_exist_check
    return
  fi
  if ((answer_regenerate >= 1)) && ((answer_regenerate <= counter)); then
    peer_to_regenerate="${peers[$answer_regenerate]}"
    generate_qr "${SERV_CONF_DIR}/${peer_to_regenerate}.conf"
  else
    echo "Wrong number. Try again."
    regenerate_qr
    return
  fi
}

remove_server() {
  ##################################################
  # Remove specified server
  ##################################################

  iface_name="$(basename "${SERV_CONF%%.conf}")"
  echo "Delete $iface_name server? Type YES to delete."
  read -e -p ":> " -r answer_delete
  case "$answer_delete" in
    YES )
      if ((IS_SLACKWARE == 0)); then
        # Systemd way
        systemctl disable --now wg-quick@"$iface_name".service
      elif ((IS_SLACKWARE == 1)); then
        # Slackware way
        sed -i.back "/wg-quick up $iface_name/d" /etc/rc.d/rc.local
        wg-quick down "$iface_name"
      fi
      rm -Rvf "$SERV_CONF_DIR" "$SERV_CONF" "${SERV_CONF}.backup"
      echo  "$iface_name server removed."
      ;;
    * )
      echo "Server $iface_name was NOT deleted. Exiting..."
      return
      ;;
  esac
}

main() {
  ##################################################
  # Main function
  ##################################################

  check_root
  serv_exist_check
}

log="/tmp/$(basename "${0/.sh/.log}")"
main 2>&1 | tee "$log"
date >> "$log"
