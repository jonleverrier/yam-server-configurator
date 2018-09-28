#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Update
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4, 18.04
#+ Release:     1.1.0
#+----------------------------------------------------------------------------+

BRANCH=$1

# Display warning if no inline variables are set
if [ -z "$1" ]; then
    echo "WARNING: No branch was specified."
    echo ""
    exit 1
fi

echo '------------------------------------------------------------------------'
echo 'Updating YAM scripts...'
echo '------------------------------------------------------------------------'

cd /usr/local/bin

# Install yam utilities
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_backup_local.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_backup_s3.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_backup_system.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_sync_s3.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_manage.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_secure.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_setup.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_update.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/${BRANCH}/yam_teleport.sh

# lock down files to root user only
chmod -R 700 /usr/local/bin/yam_backup_local.sh
chmod -R 700 /usr/local/bin/yam_backup_s3.sh
chmod -R 700 /usr/local/bin/yam_backup_system.sh
chmod -R 700 /usr/local/bin/yam_sync_s3.sh
chmod -R 700 /usr/local/bin/yam_setup.sh
chmod -R 700 /usr/local/bin/yam_manage.sh
chmod -R 700 /usr/local/bin/yam_secure.sh
chmod -R 700 /usr/local/bin/yam_update.sh
chmod -R 700 /usr/local/bin/yam_teleport.sh

echo 'Done.'
