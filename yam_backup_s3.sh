#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Backup S3
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4, 18.04
#+ Release:     1.0.0
#+----------------------------------------------------------------------------+

PATH_BACKUP='yamdigital/servers/backups'

# VARIABLES THAT ARE PASSED IN TO THE SCRIPT...
# FOR EXAMPLE "yam_backup_s3.sh yam yam-avalon-ams3-01"
USER=$1
SERVER_FOLDER=$2

s3cmd sync --delete-removed --skip-existing /home/$USER/backup/ s3://$PATH_BACKUP/$SERVER_FOLDER/home/$USER/backup/
