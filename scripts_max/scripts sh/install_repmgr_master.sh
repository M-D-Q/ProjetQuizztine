#!/bin/bash

# Set variables
MASTER_IP="your_master_ip"
SLAVE_IP="your_slave_ip"
REPMGR_USER="repmgr_user"
REPMGR_DB="repmgr_db"
REPMGR_PASSWORD="your_password"

# install repmgr (changes according to version)
curl https://dl.enterprisedb.com/default/release/get/deb | sudo bash
sudo apt-get install postgresql-12-repmgr



# create repmgr user and database
sudo -u postgres psql -c "CREATE ROLE ${REPMGR_USER} WITH REPLICATION LOGIN PASSWORD '${REPMGR_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE ${REPMGR_DB} OWNER ${REPMGR_USER};"


# update pg_hba.conf
sudo bash -c "cat << EOF >> /etc/postgresql/12/main/pg_hba.conf
host    replication     ${REPMGR_USER}         ${SLAVE_IP}/32            md5
host    ${REPMGR_DB}    ${REPMGR_USER}         ${SLAVE_IP}/32            md5
host    replication     ${REPMGR_USER}         ${MASTER_IP}/32           md5
host    ${REPMGR_DB}    ${REPMGR_USER}         ${MASTER_IP}/32           md5
EOF"

# Update postgresql.conf (uncomment then change)
sudo sed -i '/^#.*listen_addresses/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i '/^listen_addresses/s/.*/listen_addresses = '\''*'\''/' /etc/postgresql/12/main/postgresql.conf

sudo sed -i '/^#.*wal_level/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i '/^wal_level/s/.*/wal_level = '\''hot_standby'\''/' /etc/postgresql/12/main/postgresql.conf

sudo sed -i '/^#.*max_wal_senders/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i '/^max_wal_senders/s/.*/max_wal_senders = 5/' /etc/postgresql/12/main/postgresql.conf

sudo sed -i '/^#.*hot_standby/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i '/^hot_standby/s/.*/hot_standby = on/' /etc/postgresql/12/main/postgresql.conf

sudo sed -i '/^#.*wal_keep_segments/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i '/^wal_keep_segments/s/.*/wal_keep_segments = 64/' /etc/postgresql/12/main/postgresql.conf


# Create & Configure repmgr.conf
sudo mkdir /etc/repmgr
sudo bash -c "cat << EOF > /etc/repmgr/repmgr.conf
node_id=1
node_name=Master_Node
conninfo='host=${MASTER_IP} user=${REPMGR_USER} dbname=${REPMGR_DB} password=${REPMGR_PASSWORD}'
data_directory='/var/lib/postgresql/12/main'
failover=automatic
promote_command='repmgr standby promote -f /etc/repmgr/repmgr.conf --log-to-file'
follow_command='repmgr standby follow -f /etc/repmgr/repmgr.conf --log-to-file --upstream-node-id=%n'
use_replication_slots=yes
monitoring_history=yes
reconnect_attempts=1
reconnect_interval=1
service_start_command   = '/usr/bin/pg_ctlcluster 12 main start'
service_stop_command    = '/usr/bin/pg_ctlcluster 12 main stop'
service_restart_command = '/usr/bin/pg_ctlcluster 12 main restart'
service_reload_command  = '/usr/bin/pg_ctlcluster 12 main reload'
service_promote_command = '/usr/bin/pg_ctlcluster 12 main promote'
promote_check_timeout = 15
log_file='/var/log/postgresql/repmgr.log'
EOF"

#Configure Repmgrd service
sudo bash -c "cat << EOF > /etc/default/repmgrd
REPMGRD_ENABLED=yes
REPMGRD_CONF="/etc/repmgr/repmgr.conf"
REPMGRD_OPTS="--daemonize=false"
REPMGRD_USER=postgres
REPMGRD_BIN=/usr/bin/repmgrd
REPMGRD_PIDFILE=/var/run/repmgrd.pid
EOF"

# Restart PostgreSQL & stuff
sudo systemctl restart postgresql
sudo systemctl restart repmgrd

# Register master node
sudo -u postgres bash -c "repmgr -f /etc/repmgr/repmgr.conf master register"
