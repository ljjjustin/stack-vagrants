#!/bin/bash

haproxy_running=$(ps -C haproxy --no-header | wc -l)

if [ "${haproxy_running}" -ne 0 ]; then
    exit 0
fi

# try restart haproxy
systemctl restart haproxy && sleep 1

haproxy_running=$(ps -C haproxy --no-header | wc -l)
if [ "${haproxy_running}" -eq 0 ]; then
    systemctl stop keepalived
fi
exit 1
