#!/bin/bash
clear
while true; do
    clear
    echo "Current Network Connections"
    echo $HOSTNAME
    echo " "
    ./revnetcon.sh
# lsof -i -P -n +c 15 |grep EST
    sleep 5
done
