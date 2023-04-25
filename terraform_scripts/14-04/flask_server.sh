#!/bin/bash

# Define variables
MASTER_IP="10.0.1.10"
NAGIOS_SERVER_IP="10.0.1.14"
IP_PGPOOL="10.0.1.13"
SLAVE_IP="10.0.1.11"

# Update the package list
sudo apt-get update -y

# Install Python3, pip, and git if not already installed
sudo apt-get install -y python3 python3-pip git
sudo apt install  -y python3-flask

cd /home/azureuser
sudo git clone https://github.com/M-D-Q/quizztine_flask
cd quizztine_flask

#change a line in the requirements.txt
sudo sed -i "s/psycopg2==2.9.5/psycopg2-binary/g" requirements.txt

pip3 install -r requirements.txt


# Replace £ip_database£ with the actual IP address in the __init__.py file
sudo sed -i "s/£ip_database£/${IP_PGPOOL}/g" quizztine_site/__init__.py

#laucnh it
python3 app.py