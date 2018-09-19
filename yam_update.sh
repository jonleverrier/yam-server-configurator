#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Update
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4,
#+ Release:     0.0.1
#+----------------------------------------------------------------------------+

echo '------------------------------------------------------------------------'
echo 'Updating YAM scripts...'
echo '------------------------------------------------------------------------'

# Install yam utilities
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_local.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_s3.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_system.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_sync_s3.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_manage.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_secure.sh
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_setup.sh

# lock down files to root user only
chmod -R 700 /usr/local/bin/yam_backup_local.sh
chmod -R 700 /usr/local/bin/yam_backup_s3.sh
chmod -R 700 /usr/local/bin/yam_backup_system.sh
chmod -R 700 /usr/local/bin/yam_sync_s3.sh
chmod -R 700 /usr/local/bin/yam_setup.sh
chmod -R 700 /usr/local/bin/yam_manage.sh
chmod -R 700 /usr/local/bin/yam_secure.sh

echo 'Done.'
