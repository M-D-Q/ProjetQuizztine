#!/bin/bash

# Define variables
NAGIOS_HOST_IP=$1

# Update the package lists and install necessary packages
sudo apt-get update
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php7.4 libgd-dev
sudo apt-get install -y openssl libssl-dev

# Download and install Nagios Core
cd /tmp
wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.6.tar.gz
tar xzf nagioscore.tar.gz
cd /tmp/nagioscore-nagios-4.4.6/
sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all
sudo make install-groups-users
sudo usermod -a -G nagios www-data
sudo make install
sudo make install-daemoninit
sudo make install-commandmode
sudo make install-config
sudo make install-webconf

# Enable required Apache modules and allow Apache through the firewall
sudo a2enmod rewrite
sudo a2enmod cgi
sudo ufw allow Apache
sudo ufw reload

# Set up Nagios admin user
sudo htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin quizztine

# Start Apache and Nagios services
sudo systemctl restart apache2.service
sudo systemctl start nagios.service

# Install necessary packages for Nagios plugins
sudo apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext

# Download and install Nagios plugins
cd /tmp
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.3.3.tar.gz
tar zxf nagios-plugins.tar.gz
cd /tmp/nagios-plugins-release-2.3.3/
sudo ./tools/setup
sudo ./configure
sudo make
sudo make install

# Download and install NRPE
cd ~
cd /tmp
curl -L -O https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-4.1.0/nrpe-4.1.0.tar.gz
tar zxf nrpe-4.1.0.tar.gz
cd nrpe-4.1.0
./configure
sudo make check_nrpe
sudo make nrpe
sudo make install-daemon
sudo make install-config
sudo make install-init
sudo make all
sudo make install-plugin


# Enable Apache and Nagios to start at boot
sudo systemctl enable apache2 nagios
#add to commands.cfg
sudo bash -c 'cat >> /usr/local/nagios/etc/objects/commands.cfg << EOF
define command{
        command_name check_nrpe
        command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}
EOF'
#add to nagios.cfg
sudo bash -c 'cat >> /usr/local/nagios/etc/nagios.cfg << EOF
cfg_dir=/usr/local/nagios/etc/servers
EOF'

# Fill in the /usr/local/nagios/etc/host1.cfg file
sudo bash -c "cat > /usr/local/nagios/etc/host1.cfg << EOF
define host {
    use                     linux-server
    host_name               host1
    alias                   My client server (host1)
    address                 $NAGIOS_HOST_IP
    max_check_attempts      5
    check_period            24x7
    notification_interval   30
    notification_period     24x7
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Load average
    check_command           check_nrpe!check_load
}

define service {
    use                     generic-service
    host_name               host1
    service_description     /dev/vda1 free space
    check_command           check_nrpe!check_hda1
}

define service {
    use                     generic-service
    host_name               host1
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}

define service {
    use                     generic-service
    host_name               host1
    service_description     SSH
    check_command           check_ssh
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Root Partition
    check_command           check_nrpe!check_hda1
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Total Processes zombie
    check_command           check_nrpe!check_zombie_procs
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Total Processes
    check_command           check_nrpe!check_total_procs
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Current Load
    check_command           check_nrpe!check_load
}

define service {
    use                     generic-service
    host_name               host1
    service_description     Current Users
    check_command           check_nrpe!check_users
}

define service {
    use                     generic-service
    host_name               host1
    service_description     PostgreSQL locks
    check_command           check_nrpe!check_postgres_locks
}

define service {
    use                     generic-service
    host_name               host1
    service_description     PostgreSQL Bloat
    check_command           check_nrpe!check_postgres_bloat
}

define service {
    use                     generic-service
    host_name               host1
    service_description     PostgreSQL Connection
    check_command           check_nrpe!check_postgres_connection
}

define service {
    use                     generic-service
    host_name               host1
    service_description     PostgreSQL Backends
    check_command           check_nrpe!check_postgres_backends
}
EOF"

sudo systemctl restart nagios nrpe apache2
sudo systemctl enable nagios nrpe apache2
