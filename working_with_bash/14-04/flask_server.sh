#!/bin/bash

# Define variables
MASTER_IP=$1
NAGIOS_SERVER_IP=$2
IP_PGPOOL=$3
SLAVE_IP=$4

# Update the package list
sudo apt-get update -y

# Install Python3, pip, and git if not already installed
sudo apt-get install -y python3 python3-pip git

cd /home/azureuser
sudo git clone https://github.com/M-D-Q/quizztine_flask
cd quizztine_flask

#change a line in the requirements.txt
sed -i "s/psycopg2==2.9.5/psycopg2-binary/g" quizztine_site/__init__.py

pip3 install -r requirements.txt


# Replace £ip_database£ with the actual IP address in the __init__.py file
sed -i "s/£ip_database£/${IP_PGPOOL}/g" quizztine_site/__init__.py

#laucnh it
export FLASK_APP=app.py
export FLASK_RUN_HOST=0.0.0.0
flask run
