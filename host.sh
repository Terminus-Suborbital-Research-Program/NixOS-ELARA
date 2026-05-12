#!/usr/bin/env bash
sudo pkill -9 wpa_supplicant

#echo " Unblocking RFKill "
#     rfkill unblock all



echo "  Station up "
sudo hostapd_s1g -B /etc/morse/hostapd_s1g.conf

sleep 3

echo " Jupiter Interface Status "
ip a show wlan1

# Show if Odin's conencted
iw dev wlan0 station dump
#sudo hostapd_cli_s1g -p /var/run/hostapd_s1g all_sta
# iw dev wlan1 station dump || true

#echo " Starting iperf3 Server "
# exec replaces the shell with the iperf3 process
#exec iperf3 -s