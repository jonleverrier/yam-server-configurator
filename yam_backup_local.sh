#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Backup Local
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4,
#+ Release:     0.0.2
#+----------------------------------------------------------------------------+

# To be used with cron, or run manually from the command line.

# Example usage; backup websites that live in /home/jamesbond/:
# /bin/bash yam_backup_local.sh jamesbond

# This scripts presumes your user directory is organised like the following;
# /home/user/public/website1
# /home/user/public/website2
# /home/user/public/website3

# DEFAULT VARIABLES
YAM_DATEFORMAT_FULL=`date '+%Y-%m-%d'`
YAM_BACKUP_DURATION='+6'

# INLINE VARIABLES
USER=$1

# COLOURS
COLOUR_RESTORE=$(echo -en '\033[0m')
COLOUR_CYAN=$(echo -en '\033[00;36m')
COLOUR_WHITE=$(echo -en '\033[01;37m')

echo '------------------------------------------------------------------------'
echo 'Starting backup process for ${USER}'
echo '------------------------------------------------------------------------'

# if backup folder for user exists skip, else create a folder called backup
if [ -d "/home/${USER}/backup" ]; then
    echo `date +"%Y %m %d %T" - Backup folder already exists. Skipping...`
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
          echo `date +"%Y %m %d %T" - Skipping backup for ${d}...`
      else
          echo `date +"%Y %m %d %T" - Backing up ${d}...`

          # creating tempory dir for database dump
          mkdir -p /home/${USER}/backup/temp/

          # creating project dir in backup directory
          mkdir -p /home/${USER}/backup/${d##*/}/

          # dump database and place it in a tempory dir...
          echo `date +"%Y %m %d %T" - Dumping database`
          mysqldump -u root yam_db_${USER}_${d##*/} > /home/${USER}/backup/temp/yam_db_${USER}_${d##*/}.sql

          # tar database and entire web folder...
          echo `date +"%Y %m %d %T" - Compressing database and web folder`
          tar -czf /home/${USER}/backup/${d##*/}/${USER}-${d##*/}-${YAM_DATEFORMAT_FULL}.tar.gz /home/${USER}/backup/temp /home/${USER}/public/${d##*/}

          # clean up data in temp folder...
          echo `date +"%Y %m %d %T" - Cleaning up temporary folder`
          rm -rf /home/${USER}/backup/temp

          # delete old backups...
          echo `date +"%Y %m %d %T" - Checking for old backups to delete`
          if [ -d "/home/${USER}/backup/${d##*/}/" ]; then
              find /home/${USER}/backup/${d##*/}/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
          fi

      fi
      # END BACKUP PROCESS

  fi
done

echo `date +"%Y %m %d %T" - Backup for ${USER} complete.`
