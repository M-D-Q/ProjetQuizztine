#!/bin/bash

NAGIOS_HOST_IP=$1
NAGIOS_SERVER_IP=$2
IP_PGPOOL="xxxx" 

# Create nagios user
sudo useradd nagios

# Update system packages
sudo apt update

# Install necessary packages
sudo apt install -y autoconf gcc libperl-dev libmcrypt-dev make libssl-dev wget dc build-essential gettext libdbd-pg-perl postgresql-12 postgresql-client pgloader 
sudo apt install -y libnagios-plugin-perl

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

#Clone the git repo
cd /tmp
git clone https://github.com/M-D-Q/quizztine_flask.git


#Setup postgresql
sudo -u postgres bash << EOF
psql -c "CREATE USER nagios WITH PASSWORD 'quizztine';"
psql -c "ALTER USER nagios WITH SUPERUSER;"
psql -c "CREATE DATABASE quizztine_db;"
psql -c "ALTER USER postgres WITH PASSWORD 'kek';"
EOF

#convert old db to new db
cd /tmp 
sudo pgloader sqlite:///tmp/quizztine_flask/quizztine_site/data.sqlite pgsql://postgres:kek@localhost/quizztine_db
#cover problems after conversion (autoincrement goes missing)
sudo -u postgres bash << EOF
psql -c "\c quizztine_db;"
psql -c "CREATE SEQUENCE users_id_seq;"
psql -c "ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq');"
EOF


#Modify /etc/postgresql/12/main/pg_hba.conf
sudo bash -c "echo 'host    all             all             10.3.0.4/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"
sudo bash -c "echo 'host    all             quizztine_db             $IP_PGPOOL             md5' >> /etc/postgresql/12/main/pg_hba.conf"

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
sudo sed -i "s/^server_address=.*/server_address=$NAGIOS_HOST_IP/g" /usr/local/nagios/etc/nrpe.cfg
sudo sed -i "s/^allowed_hosts=.*/allowed_hosts=127.0.0.1,::1,$NAGIOS_SERVER_IP/g" /usr/local/nagios/etc/nrpe.cfg

##############################################################################################################
####################################### SET UP PROMETHEUS EXPORTER############################################
##############################################################################################################

# Set variables
exporter_version="0.11.1"
exporter_url="https://github.com/prometheus-community/postgres_exporter/releases/download/v${exporter_version}/postgres_exporter-${exporter_version}.linux-amd64.tar.gz"


# Create a new system user for the exporter without a home directory, 
# not able to login, and with the 'nologin' shell
sudo useradd --system --no-create-home --shell /usr/sbin/nologin postgres_exporter

# Download the exporter archive
wget -O postgres_exporter.tar.gz $exporter_url

# Create a temporary directory and extract the archive to it
mkdir temp_postgres_exporter
tar -xzf postgres_exporter.tar.gz -C temp_postgres_exporter --strip-components=1

# Move the postgres_exporter binary to /usr/local/bin
sudo mv temp_postgres_exporter/postgres_exporter /usr/local/bin/

# Set ownership of the binary to the postgres_exporter user and group
sudo chown postgres_exporter:postgres_exporter /usr/local/bin/postgres_exporter

# Clean up the temporary files
rm -rf temp_postgres_exporter postgres_exporter.tar.gz

# Create a systemd service file
sudo bash -c "cat > /etc/systemd/system/postgres_exporter.service << EOL
[Unit]
Description=Prometheus PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:9187 --web.telemetry-path=/metrics

[Install]
WantedBy=multi-user.target
EOL"

# Reload systemd and start the exporter
sudo systemctl daemon-reload
sudo systemctl enable postgres_exporter
sudo systemctl start postgres_exporter

# Print the status of the exporter
sudo systemctl status postgres_exporter


##############################################################################################################
####################################### SET UP REPMGR ########################################################
##############################################################################################################


# Set variables
MASTER_IP="your_master_ip"
SLAVE_IP="your_slave_ip"
REPMGR_USER="repmgr_user"
REPMGR_DB="repmgr_db"
REPMGR_PASSWORD="quizztine"

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