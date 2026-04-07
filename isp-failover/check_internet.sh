#!/bin/ksh

default_gw="<PROVIDER1_GW>"
triolan_gw="<PROVIDER2_GW>"

pkill -9 -f wrapper.sh
/bin/echo $(/bin/date +"%d-%m-%y %H:%M:%S") Started
/bin/echo "$$" > /var/run/checkInet.pid


checkProvider1 () {

/sbin/route add -inet 8.8.8.8 <PROVIDER1_GW> > /dev/null

sleep 1

if /sbin/ping -I <PROVIDER1_SRC_IP> -q -c 1 8.8.8.8 > /dev/null; then
    /bin/echo "$Date Provider1 restored"
    /bin/echo "Action: switch to Provider1"

    /sbin/route change default <PROVIDER1_GW> > /dev/null

    /sbin/pfctl -f /etc/pf.conf

    /sbin/ipsecctl -F
    /sbin/ipsecctl -f /etc/ipsec.conf

    /usr/bin/ssh -i /etc/ssh/ssh_host_rsa_key <INTERNAL_HOST> '/root/remoteGateways.sh /root/loadipsec'

    /usr/local/bin/mutt -s "Office1 main Internet has been restored." -- <ADMIN_EMAIL>,<TEAM_EMAIL>

    WgetFailed=false
    PingFailed=false
fi

/sbin/route delete 8.8.8.8 > /dev/null
}


checkGoogle () {

Date=$(/bin/date +"%d-%m-%y %H:%M:%S")
WgetFailed=false
PingFailed=false

if ! /usr/local/bin/wget -q --no-check-certificate --spider --tries=2 --timeout=2 https://www.google.com/ ; then
    /bin/echo "$Date $Provider wget google failed"
    WgetFailed=true
fi

if ! /sbin/ping -I $PingSrc -q -c 1 8.8.8.8 > /dev/null; then
    /bin/echo "$Date $Provider ping google failed"
    PingFailed=true
fi

if [ $Provider = Provider2 ]; then
    checkProvider1
fi

}


while :; do

current_gw=$(/usr/bin/netstat -rn | /usr/bin/head -5 | /usr/bin/tail -1 | /usr/bin/awk '{print $2}')

case $current_gw in
    $default_gw)    PingSrc="<PROVIDER1_SRC_IP>"
                    Provider=Provider1
                    Switch=Provider2
                    ChangeGW=$triolan_gw
                    IPSEC=/etc/ipsecProvider2.conf
                    PFCONF=/etc/pfProvider2.conf
                    IPSECREMOTE=/root/loadipsecProvider2
                    Timeout=60
    ;;
    $triolan_gw)    PingSrc="<PROVIDER2_SRC_IP>"
                    Provider=Provider2
                    Switch=Provider1
                    ChangeGW=$default_gw
                    IPSEC=/etc/ipsec.conf
                    PFCONF=/etc/pf.conf
                    IPSECREMOTE=/root/loadipsec
                    Timeout=30
    ;;
esac

checkGoogle

if $PingFailed && $WgetFailed ; then

    /bin/echo "Action: switch to $Switch"

    /sbin/route change default $ChangeGW > /dev/null

    /sbin/pfctl -f $PFCONF

    /sbin/ipsecctl -F
    /sbin/ipsecctl -f $IPSEC

    /usr/bin/ssh -i /etc/ssh/ssh_host_rsa_key <INTERNAL_HOST> "/root/remoteGateways.sh $IPSECREMOTE"

    /usr/local/bin/mutt -s "Office1 Internet. Action: switch to $Switch." -- <ADMIN_EMAIL>,<TEAM_EMAIL> < /home/body.txt

fi

sleep $Timeout

done
