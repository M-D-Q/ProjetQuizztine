#!/bin/bash

# VM running HAproxy & ETCD


#Get variables
IP_ETCD=10.3.0.11


#install etcd and haproxy
sudo apt-get update
sudo apt-get install -y etcd haproxy


sudo bash -c "cat << EOF >> /etc/default/etcd
ETCD_LISTEN_PEER_URLS="http://$IP_ETCD:2380"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://$IP_ETCD:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$IP_ETCD:2380"
ETCD_INITIAL_CLUSTER="etcd0=http://$IP_ETCD:2380,"
ETCD_ADVERTISE_CLIENT_URLS="http://$IP_ETCD:2379"
ETCD_INITIAL_CLUSTER_TOKEN="cluster1"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF"

sudo systemctl restart etcd


#setup haproxy
sudo bash -c "cat << EOF > /etc/haproxy/haproxy.cfg
global
    maxconn 100
defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s
listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /
listen postgres
    bind *:5000
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server postgresql1 10.3.0.4:5432 maxconn 100 check port 8008
    server postgresql2 10.3.0.12:5432 maxconn 100 check port 8008
EOF"

sudo systemctl restart haproxy

