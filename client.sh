#!/usr/bin/env bash

sudo pkill -9 wpa_supplicant

sudo wpa_supplicant_s1g -B -Dnl80211 -i wlu1 -c/etc/morse/wpa_s1g.conf -s

echo "Waiting for Wi-Fi association and connection to Jupiter (10.0.0.1)..."
# Ping Jupiter continuously until we get a response
until ping -c 1 -W 1 10.0.0.1 >/dev/null 2>&1; do
    sleep 2
done

echo " Link Established! "

echo " Odin Interface Status "
ip a show wlu1

echo " WPA Supplicant Status "
wpa_cli_s1g -p /var/run/wpa_supplicant_s1g status || true

echo " Show link "
iw dev wlu1 link || true

echo " 5-Packet Ping Test "
ping -c 5 10.0.0.1

echo " Running UDP Throughput Test (1 Mbps) "
iperf3 -c 10.0.0.1 -u -b 1M