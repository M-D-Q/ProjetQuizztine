#!/bin/bash

NAGIOS_HOST_IP=$1
NAGIOS_SERVER_IP=$2

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


####### SET UP MASTER SLAVE REPLCIATION
sudo -u postgres bash << EOF
psql -c "CREATE ROLE test WITH REPLICATION PASSWORD 'replication' LOGIN;"
EOF
sudo bash -c "echo 'host    replication     test            $IP_SLAVE/32             md5' >> /etc/postgresql/12/main/pg_hba.conf"
sudo systemctl restart postgresql postgresql@12-main


#stuff
sudo systemctl restart nrpe 
sudo systemctl enable nrpe
