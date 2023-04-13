#!/bin/bash

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
