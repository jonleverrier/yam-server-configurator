#!/bin/bash

# YAM backup to Amazon S3
# by Jon Leverrier (jon@youandme.digital)
# Version 0.1

# /bin/bash yam_backup_s3.sh yam yam-avalon-ams3-01

PATH_BACKUP='yamdigital/servers/backups'

# VARIABLES THAT ARE PASSED IN TO THE SCRIPT...
# FOR EXAMPLE "yam_backup_s3.sh yam yam-avalon-ams3-01"
USER=$1
SERVER_FOLDER=$2

s3cmd sync --delete-removed --skip-existing /home/$USER/backup/ s3://$PATH_BACKUP/$SERVER_FOLDER/home/$USER/backup/
