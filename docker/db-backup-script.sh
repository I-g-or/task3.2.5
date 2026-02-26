#!/bin/bash

# Load global environment variables
. /etc/environment

# Required variables
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/home/ec2-user/db-backups"
S3_BUCKET="ghostfolio-backup-db"
CONTAINER_NAME="postgres"
DB_NAME="ghostfolio-db"
DB_USER="user"
DB_PASSWORD="123456"
BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"

# Create backup
echo "Starting backup at $(date)"
sudo docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_FILE

# Upload to S3
sudo aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/

if [ $? -eq 0 ]; then
  echo "Backup has been successfully uploaded to S3 [$(date)] "
else
  echo "[$(date)] ERROR! Failed to upload backup to S3!" >&2
  exit 1
fi

# Remove local backups older than 3 days
find $BACKUP_DIR -type f -name "*.gz" -mtime +3 -delete

echo "Backup completed at [$(date)]"
