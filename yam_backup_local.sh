#!/bin/bash

# YAM BACKUP LOCAL
# by Jon Leverrier (jon@youandmedigital.com)
# Version 0.2

# To be used with cron, or run manually from the command line.

# Example usage; backup websites that live in /home/jamesbond/:
# /bin/bash yam_backup_local.sh jamesbond

# This scripts presumes your user directory is organised like the following;
# /home/user/public/website1
# /home/user/public/website2
# /home/user/public/website3

# DEFAULT VARIABLES
DATE_FULL=`date '+%Y-%m-%d'`
BACKUP_DURATION_TIME='+6'

# INLINE VARIABLES
USER=$1

# COLOURS
RESTORE=$(echo -en '\033[0m')
CYAN=$(echo -en '\033[00;36m')
WHITE=$(echo -en '\033[01;37m')

echo "${WHITE}>>${RESTORE}"
echo "${WHITE}>> Starting backup process for ${USER} ${RESTORE}"
echo "${WHITE}>>${RESTORE}"

# if backup folder for user exists skip, else create a folder called backup
if [ -d "/home/${USER}/backup" ]; then
    echo "Backup folder already exists. Skipping..."
else
    # make backup dir for user
    mkdir -p /home/${USER}/backup
fi

# cycle through user public folder looking for websites
for d in /home/${USER}/public/*; do
  if [ -d "$d" ]; then

      # START BACKUP PROCESS
      # $d variable outputs /home/<USER>/public/<FOLDER>
      # ${d##*/} variable outputs <FOLDER>

      # if .nobackup exists in a directory, skip the backup process
      if [ -e $d/.nobackup ]; then
          echo "Skipping backup for ${d}..."
      else
          echo "Backing up ${d}..."

          # creating tempory dir for database dump
          mkdir -p /home/${USER}/backup/temp/

          # creating project dir in backup directory
          mkdir -p /home/${USER}/backup/${d##*/}/

          # dump database and place it in a tempory dir...
          echo "${CYAN}-- Dumping database ${RESTORE}"
          mysqldump -u root yam_db_${USER}_${d##*/} > /home/${USER}/backup/temp/yam_db_${USER}_${d##*/}.sql

          # tar database and entire web folder...
          echo "${CYAN}-- Compressing database and web folder ${RESTORE}"
          tar -czf /home/${USER}/backup/${d##*/}/${USER}-${d##*/}-${DATE_FULL}.tar.gz /home/${USER}/backup/temp /home/${USER}/public/${d##*/}

          # clean up data in temp folder...
          echo "${CYAN}-- Cleaning up tempory folder ${RESTORE}"
          rm -rf /home/${USER}/backup/temp

          # delete old backups...
          echo "${CYAN}-- Checking for old backups to delete ${RESTORE}"
          if [ -d "/home/${USER}/backup/${d##*/}/" ]; then
              find /home/${USER}/backup/${d##*/}/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
          fi

      fi
      # END BACKUP PROCESS

  fi
done

echo "${WHITE}>> Backup for ${USER} complete.${RESTORE}"
