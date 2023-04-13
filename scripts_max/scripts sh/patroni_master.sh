#!/bin/bash

#Get Variables 
export MASTER_IP=10.3.0.4
export REPLICA_IP=10.3.0.12
export ETCD_IP=10.3.0.11

# Install PostgreSQL-12, Patroni & dependencies
sudo apt update
sudo apt install -y postgresql-12 postgresql-client-12
sudo apt install -y python3-pip
sudo pip install psycopg2-binary
sudo pip install patroni[etcd]
sudo systemctl stop postgresql

sudo ln -s /usr/lib/postgresql/12/bin/pg_ctl /usr/bin/
sudo mkdir /data/patroni -p
sudo chown postgres:postgres /data/patroni
sudo chmod 700 /data/patroni
sudo chmod 700 /data/patroni/
sudo install -o postgres -g postgres -m 0750 -d /var/log/patroni/my-pg-cluster

# Patroni.yml 
sudo bash -c "cat << EOF > /etc/patroni.yml
scope: postgres
namespace: /db/
name: node1

restapi:
  listen: ${MASTER_IP}:8008
  connect_address: ${MASTER_IP}:8008

log:
  level: INFO
  dir: /var/log/patroni/my-pg-cluster


etcd:
  host: ${ETCD_IP}:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_segment: 8
        max_wal_senders: 5
        max_replication_slots: 5
        checkpoint_timeout: 30

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator ${MASTER_IP}/0 md5
  - host replication replicator ${REPLICA_IP}/0 md5
  - host all all 0.0.0.0/0 md5

  users:
    admin:
      password: admin
      options:
      - createrole
      - createdb
    replicator:
      password: replication
      options:
        - replication

postgresql:
  listen: ${MASTER_IP}:5432
  connect_address: ${MASTER_IP}:5432
  data_dir: /data/patroni
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: replication
    superuser:
      username: admin
      password: admin
    rewind:
      username: rewind_user
      password: password_rewind
  parameters:
    unix_socket_directories: '.'

tags: 
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF"

# patroni daemon
sudo bash -c "cat << EOF > /etc/systemd/system/patroni.service
[Unit]
Description=High availability PostgreSQL Cluster
After=syslog.target network.target

[Service]
Type=simple
User=postgres
Group=postgres
Environment=PATH=/usr/lib/postgresql/12/bin:$PATH
ExecStart=/usr/local/bin/patroni /etc/patroni.yml
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF"


# Update .bashrc for the postgres user
sudo bash -c 'echo "export PATH=$PATH:/usr/lib/postgresql/12/bin" > /var/lib/postgresql/.bashrc'
sudo chown postgres:postgres /var/lib/postgresql/.bashrc

# Apply the changes
sudo su - postgres -c 'source /var/lib/postgresql/.bashrc'


#sudo systemctl daemon-reload && sudo systemctl start patroni
