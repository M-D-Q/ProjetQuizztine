sudo apt-get update
sudo apt-get install postgresql-client
sudo mkdir /var/backups/postgresql
sudo chown postgres:postgres /var/backups/postgresql
sudo nano /usr/local/bin/backup_postgresql.sh

    #!/bin/bash

    # Configuration
    BACKUP_DIR="/var/backups/postgresql"
    DB_USER="your_db_user"
    DB_NAME="your_db_name"
    DB_HOST="your_pg_server_ip"

    # Timestamp for the backup file
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    # Perform the backup
    pg_dump -U $DB_USER -h $DB_HOST -Fc $DB_NAME -f $BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump

    # Remove backups older than 7 days
    find $BACKUP_DIR -type f -mtime +7 -exec rm {} \;

sudo chmod +x /usr/local/bin/backup_postgresql.sh
sudo /usr/local/bin/backup_postgresql.sh

