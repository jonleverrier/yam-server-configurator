#!/bin/bash

# YAM backup to Amazon S3
# by Jon Leverrier (jon@youandme.digital)
# Version 0.1

# /bin/bash yam_backup_s3.sh yam

# COLOURS
RESTORE=$(echo -en '\033[0m')
CYAN=$(echo -en '\033[00;36m')
WHITE=$(echo -en '\033[01;37m')

# VARIABLES THAT ARE PASSED IN TO THE SCRIPT...
# FOR EXAMPLE "yam_backup_s3.sh yam yam-avalon-ams3-01"
USER=$1
SERVER_FOLDER=$2

s3cmd sync --delete-removed --skip-existing /home/$USER/backup/ s3://yamdigital/servers/backups/$SERVER_FOLDER/home/$USER/backup/
