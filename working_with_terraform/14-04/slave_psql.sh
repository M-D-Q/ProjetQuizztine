#!/bin/bash

MASTER_IP="10.0.1.10"
NAGIOS_SERVER_IP="10.0.1.14"
IP_PGPOOL="10.0.1.13"
SLAVE_IP="10.0.1.11"
REPMGR_USER="repmgr"
REPMGR_DB="repmgr_db"
REPMGR_PASSWORD="quizztine"


# Create nagios user
sudo useradd nagios

# Update system packages
sudo apt update

# Install necessary packages
sudo apt install -y autoconf gcc libperl-dev libmcrypt-dev make libssl-dev wget dc build-essential gettext libdbd-pg-perl postgresql-12 postgresql-client pgloader 


# Download and install Nagios plugins
cd ~
curl -L -O https://github.com/nagios-plugins/nagios-plugins/releases/download/release-2.4.2/nagios-plugins-2.4.2.tar.gz
tar zxf nagios-plugins-2.4.2.tar.gz
cd nagios-plugins-2.4.2
./configure
make
sudo make install

# Download and install NRPE
cd ~
cd /tmp
curl -L -O https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-4.1.0/nrpe-4.1.0.tar.gz
tar zxf nrpe-4.1.0.tar.gz
cd nrpe-4.1.0
./configure
make check_nrpe
make nrpe
sudo make install-daemon
sudo make install-config
sudo make install-init

#Download and install check_postgres
cd ~
cd /tmp
git clone https://github.com/bucardo/check_postgres.git
cd check_postgres
cp check_postgres.pl /usr/local/nagios/libexec/
cd /usr/local/nagios/libexec/
perl check_postgres.pl --symlinks

#MODIFY PG SERVICE
sudo bash -c "cat >> /etc/postgresql-common/pg_service.conf << EOF
[quizztine_db]
host=localhost
port=5432
user=nagios
password=quizztine
dbname=quizztine_db
sslmode=require
EOF"

#Modify /etc/postgresql/12/main/pg_hba.conf
sudo bash -c
sudo bash -c "echo 'host    all             all             $MASTER_IP/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"
sudo bash -c "echo 'host    all             all             $SLAVE_IP/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"
sudo bash -c "echo 'host    all             quizztine_db    $IP_PGPOOL/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"
sudo bash -c "echo 'host    all             all             $IP_PGPOOL/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"


#Modify /etc/postgresql/12/main/postgresql.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf

#Add commands to nrpe.cfg
sudo bash -c "cat << EOF >> /usr/local/nagios/etc/nrpe.cfg
command[check_users]=/usr/local/nagios/libexec/check_users -w 5 -c 10
command[check_load]=/usr/local/nagios/libexec/check_load -r -w .15,.10,.05 -c .30,.25,.20
command[check_hda1]=/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /dev/root
command[check_zombie_procs]=/usr/local/nagios/libexec/check_procs -w 5 -c 10 -s Z
command[check_total_procs]=/usr/local/nagios/libexec/check_procs -w 150 -c 200
command[check_postgres_locks]=/usr/local/nagios/libexec/check_postgres_locks -w 2 -c 3 -H=localhost -u=nagios --dbpass=quizztine --dbname=quizztine_db
command[check_postgres_bloat]=/usr/local/nagios/libexec/check_postgres_bloat -w='100 M' -c='200 M' -H=localhost --dbpass=quizztine --dbname=quizztine_db -u=nagios
command[check_postgres_connection]=/usr/local/nagios/libexec/check_postgres_connection --db=quizztine_db -H=localhost --dbpass=quizztine --dbname=quizztine_db -u=nagios
command[check_postgres_backends]=/usr/local/nagios/libexec/check_postgres_backends -w=3 -c=100 -H=localhost --dbpass=quizztine --dbname=quizztine_db -u=nagios
EOF"

#add other stuff to nrpe.cfg 
sudo sed -i "s/^server_address=.*/server_address=$SLAVE_IP/g" /usr/local/nagios/etc/nrpe.cfg
sudo sed -i "s/^allowed_hosts=.*/allowed_hosts=127.0.0.1,::1,$NAGIOS_SERVER_IP/g" /usr/local/nagios/etc/nrpe.cfg

#stuff

sudo systemctl enable nrpe
sudo systemctl restart nrpe 

###################################################################
##############         REP MGR INSTALL          ###################
###################################################################

# update pg_hba.conf
sudo bash -c "cat << EOF >> /etc/postgresql/12/main/pg_hba.conf
local   replication     ${REPMGR_USER}                                  trust
host    ${REPMGR_DB}    ${REPMGR_USER}         ${SLAVE_IP}/32            trust
host    replication     ${REPMGR_USER}         ${MASTER_IP}/32           trust
host    ${REPMGR_DB}    ${REPMGR_USER}         ${MASTER_IP}/32           trust
host    replication     ${REPMGR_USER}         ${SLAVE_IP}/32            md5
host    ${REPMGR_DB}    ${REPMGR_USER}         ${SLAVE_IP}/32            md5
host    replication     ${REPMGR_USER}         ${MASTER_IP}/32           md5
host    ${REPMGR_DB}    ${REPMGR_USER}         ${MASTER_IP}/32           md5
EOF"





# install repmgr (changes according to version)
curl https://dl.enterprisedb.com/default/release/get/deb | sudo bash
sudo apt-get install -y postgresql-12-repmgr repmgr-common

# Stop PostgreSQL
sudo systemctl stop postgresql
sleep 65
sudo systemctl status postgresql | cat

sudo rm -rf /var/lib/postgresql/12/main/


# Clone master data
sudo -u postgres bash
export PGPASSWORD='quizztine'
repmgr -h ${MASTER_IP} -U ${REPMGR_USER} -d ${REPMGR_DB} -D /var/lib/postgresql/12/main/ --force standby clone
unset PGPASSWORD
exit

# Create & Configure repmgr.conf
sudo mkdir /etc/repmgr
sudo bash -c "cat << EOF > /etc/repmgr/repmgr.conf
node_id=2
node_name=Slave_Node
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

sudo sed -i '/^#.*shared_preload_libraries/s/^#//' /etc/postgresql/12/main/postgresql.conf
sudo sed -i "/^shared_preload_libraries/s/.*/shared_preload_libraries = 'repmgr'/" /etc/postgresql/12/main/postgresql.conf


# Start PostgreSQL & stuff
sudo systemctl restart repmgrd
sudo systemctl start postgresql

# Register standby node
sudo -u postgres bash -c "repmgr -f /etc/repmgr/repmgr.conf standby register"