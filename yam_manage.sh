#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Server Manager
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4, 18.04
#+ Release:     1.0.0
#+----------------------------------------------------------------------------+

# Change these settings below before running the script for the first time
YAM_EMAIL_BUG=$(echo -en 'bugs@youandme.digital')
YAM_DATEFORMAT_TIMEZONE=$(echo -en 'Europe/Paris')

# if you have a MODX basesite that you work from enter the details below
YAM_BASESITE_PATH=$(echo -en '/home/yam/public/alphasite/')
YAM_BASESITE_DB=$(echo -en 'yam_db_yam_alphasite')

# new databases or db users will be prefixed with these values.
# For example: yam_db_user_project
YAM_DATABASE_DB=$(echo -en 'yam_db')
YAM_DATABASE_USER=$(echo -en 'yam_dbuser')

# initial password for protected directories. can be overriden
# after setup
YAM_PASSWORD_GENERIC=$(openssl rand -base64 24)

# S3 backup settings
YAM_SERVER_NAME=$(echo -en 'yam-avalon-ams3-01')
YAM_DATEFORMAT_FULL=`date '+%Y-%m-%d'`

# Colour options
COLOUR_RESTORE=$(echo -en '\033[0m')
COLOUR_RED=$(echo -en '\033[00;31m')
COLOUR_GREEN=$(echo -en '\033[00;32m')
COLOUR_YELLOW=$(echo -en '\033[00;33m')
COLOUR_BLUE=$(echo -en '\033[00;34m')
COLOUR_MAGENTA=$(echo -en '\033[00;35m')
COLOUR_PURPLE=$(echo -en '\033[00;35m')
COLOUR_CYAN=$(echo -en '\033[00;36m')
COLOUR_LIGHTGRAY=$(echo -en '\033[00;37m')
COLOUR_LRED=$(echo -en '\033[01;31m')
COLOUR_LGREEN=$(echo -en '\033[01;32m')
COLOUR_LYELLOW=$(echo -en '\033[01;33m')
COLOUR_LMAGENTA=$(echo -en '\033[01;35m')
COLOUR_LPURPLE=$(echo -en '\033[01;35m')
COLOUR_LCYAN=$(echo -en '\033[01;36m')
COLOUR_WHITE=$(echo -en '\033[01;37m')

# Setup up yes no questions
# taken from https://djm.me/ask
# nothing to edit here...
ask() {
    local prompt default reply

    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from
        # somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

# check if root user
if [ "${EUID}" != 0 ];
then
    echo '------------------------------------------------------------------------'
    echo 'YAM Manager should be executed as the root user. Please switch to the'
    echo 'root user and try again'
    echo '------------------------------------------------------------------------'
    exit
fi

# Load install basesite function
installBasesite() {
    if ask "Are you sure you want to setup a new Basesite? This will inject MODX into an existing website?"; then
        read -p "Existing project name : " PROJECT_NAME
        read -p "Existing project owner : " PROJECT_OWNER
        read -s -p "Existing project MYSQL password : " PASSWORD_MYSQL
        echo
        read -p "Existing project test URL : " PROJECT_DOMAIN
        read -p "Name of MODX folder (without zip) : " FOLDER_MODX_ZIP
        read -p "URL to MODX zip : " URL_MODX
        read -p "URL to database dump : " URL_DATABASE
        read -p "URL to assets zip : " URL_ASSETS
        read -p "URL to packages zip : " URL_PACKAGES
        read -p "URL to components zip : " URL_COMPONENTS
        echo '------------------------------------------------------------------------'
        echo 'Injecting MODX into /home/$PROJECT_OWNER/public/$PROJECT_NAME'
        echo '------------------------------------------------------------------------'

        # if the website exists, continue...
        if [ -d "/home/${PROJECT_OWNER}/public/${PROJECT_NAME}" ]; then

            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}

            # Stop backups
            touch /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/.nobackup

            echo "${COLOUR_WHITE}>> fetching MODX...${COLOUR_RESTORE}"

            # Install MODX
            wget -N ${URL_MODX}

            # Unzip folder
            unzip ${FOLDER_MODX_ZIP}.zip

            # Move files inside modx folder up a level
            mv /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/${FOLDER_MODX_ZIP}/{.,}* /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/

            # Clean up installation
            rm -rf ${FOLDER_MODX_ZIP}
            rm ${FOLDER_MODX_ZIP}.zip

            echo "${COLOUR_WHITE}>> installing assets...${COLOUR_RESTORE}"
            # Install assets folder
            wget -N ${URL_ASSETS}
            unzip -o assets.zip
            rm assets.zip

            # Install packages and components
            cd core

            echo "${COLOUR_WHITE}>> installing components...${COLOUR_RESTORE}"
            # Components
            wget -N ${URL_COMPONENTS}
            unzip -o components.zip
            rm components.zip

            echo "${COLOUR_WHITE}>> installing packages...${COLOUR_RESTORE}"
            # Packages
            wget -N ${URL_PACKAGES}
            unzip -o packages.zip
            rm packages.zip

            echo "${COLOUR_WHITE}>> deleting existing config files in root, core, manager and connectors... ${COLOUR_RESTORE}"
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/config/config.inc.php
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/config.core.php
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/config.core.php
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/config.core.php

            echo "${COLOUR_WHITE}>> installing new MODX config files...${COLOUR_RESTORE}"

            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = '${YAM_DATABASE_USER}_${PROJECT_OWNER}_${PROJECT_NAME}';
\$database_password = '${PASSWORD_MYSQL}';
\$database_connection_charset = 'utf8';
\$dbase = '${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME};charset=utf8';
\$config_options = array (
);
\$driver_options = array (
);

\$lastInstallTime = 1526050719;

\$site_id = '${PROJECT_OWNER}${PROJECT_NAME}modx5af5af9faea5b6.77147055';
\$site_sessionname = '${PROJECT_OWNER}${PROJECT_NAME}SN5af5af09710f3';
\$https_port = '443';
\$uuid = '2c109d9c-4d41-4b8b-a961-84457ae83978';

if (!defined('MODX_CORE_PATH')) {
    \$modx_core_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/';
    define('MODX_CORE_PATH', \$modx_core_path);
}
if (!defined('MODX_PROCESSORS_PATH')) {
    \$modx_processors_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/model/modx/processors/';
    define('MODX_PROCESSORS_PATH', \$modx_processors_path);
}
if (!defined('MODX_CONNECTORS_PATH')) {
    \$modx_connectors_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/';
    \$modx_connectors_url= '/connectors/';
    define('MODX_CONNECTORS_PATH', \$modx_connectors_path);
    define('MODX_CONNECTORS_URL', \$modx_connectors_url);
}
if (!defined('MODX_MANAGER_PATH')) {
    \$modx_manager_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/';
    \$modx_manager_url= '/manager/';
    define('MODX_MANAGER_PATH', \$modx_manager_path);
    define('MODX_MANAGER_URL', \$modx_manager_url);
}
if (!defined('MODX_BASE_PATH')) {
    \$modx_base_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/';
    \$modx_base_url= '/';
    define('MODX_BASE_PATH', \$modx_base_path);
    define('MODX_BASE_URL', \$modx_base_url);
}
if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
    \$isSecureRequest = false;
} else {
    \$isSecureRequest = ((isset (\$_SERVER['HTTPS']) && strtolower(\$_SERVER['HTTPS']) == 'on') || \$_SERVER['SERVER_PORT'] == \$https_port);
}
if (!defined('MODX_URL_SCHEME')) {
    \$url_scheme=  \$isSecureRequest ? 'https://' : 'http://';
    define('MODX_URL_SCHEME', \$url_scheme);
}
if (!defined('MODX_HTTP_HOST')) {
    if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
        \$http_host='localhost';
        define('MODX_HTTP_HOST', \$http_host);
    } else {
        \$http_host= array_key_exists('HTTP_HOST', \$_SERVER) ? htmlspecialchars(\$_SERVER['HTTP_HOST'], ENT_QUOTES) : 'localhost';
        if (\$_SERVER['SERVER_PORT'] != 80) {
            \$http_host= str_replace(':' . \$_SERVER['SERVER_PORT'], '', \$http_host); // remove port from HTTP_HOST
        }
        \$http_host .= (\$_SERVER['SERVER_PORT'] == 80 || \$isSecureRequest) ? '' : ':' . \$_SERVER['SERVER_PORT'];
        define('MODX_HTTP_HOST', \$http_host);
    }
}
if (!defined('MODX_SITE_URL')) {
    \$site_url= \$url_scheme . \$http_host . MODX_BASE_URL;
    define('MODX_SITE_URL', \$site_url);
}
if (!defined('MODX_ASSETS_PATH')) {
    \$modx_assets_path= '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/assets/';
    \$modx_assets_url= '/assets/';
    define('MODX_ASSETS_PATH', \$modx_assets_path);
    define('MODX_ASSETS_URL', \$modx_assets_url);
}
if (!defined('MODX_LOG_LEVEL_FATAL')) {
    define('MODX_LOG_LEVEL_FATAL', 0);
    define('MODX_LOG_LEVEL_ERROR', 1);
    define('MODX_LOG_LEVEL_WARN', 2);
    define('MODX_LOG_LEVEL_INFO', 3);
    define('MODX_LOG_LEVEL_DEBUG', 4);
}
if (!defined('MODX_CACHE_DISABLED')) {
    \$modx_cache_disabled= false;
    define('MODX_CACHE_DISABLED', \$modx_cache_disabled);
}
EOF

            # Add manager config for MODX
            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/config.core.php << EOF
<?php
/*
* This file is managed by the installation process.  Any modifications to it may get overwritten.
* Add customizations to the $config_options array in \`core/config/config.inc.php\`.
*
*/
define('MODX_CORE_PATH', '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/config.core.php << EOF
<?php
/*
* This file is managed by the installation process.  Any modifications to it may get overwritten.
* Add customizations to the $config_options array in \`core/config/config.inc.php\`.
*
*/
define('MODX_CORE_PATH', '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Add root config for MODX
            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/config.core.php << EOF
<?php
/*
* This file is managed by the installation process.  Any modifications to it may get overwritten.
* Add customizations to the $config_options array in \`core/config/config.inc.php\`.
*
*/
define('MODX_CORE_PATH', '/home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Secure / change permissions on config file after save
            echo "${COLOUR_CYAN}-- adjusting MODX permissions for config files...${COLOUR_RESTORE}"
            chmod -R 644 /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/config/config.inc.php
            chmod -R 644 /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/config.core.php
            chmod -R 644 /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/config.core.php
            chmod -R 644 /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/config.core.php

            # Import database
            echo "${COLOUR_WHITE}>> importing database...${COLOUR_RESTORE}"
            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}
            wget -N ${URL_DATABASE}

            # Import basesite database
            echo "${COLOUR_CYAN}-- importing ${URL_DATABASE##*/}...${COLOUR_RESTORE}"
            mysql -u${YAM_DATABASE_USER}_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME} < /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/${URL_DATABASE##*/}

            echo "${COLOUR_CYAN}-- adding db_changepaths.sql...${COLOUR_RESTORE}"
            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/db_changepaths.sql << EOF
UPDATE \`modx_context_setting\` SET \`value\`='${PROJECT_DOMAIN}' WHERE \`context_key\`='en' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${PROJECT_DOMAIN}' WHERE \`context_key\`='fr' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${PROJECT_DOMAIN}' WHERE \`context_key\`='es' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${PROJECT_DOMAIN}' WHERE \`context_key\`='pdf' AND \`key\`='http_host';

UPDATE \`modx_context_setting\` SET \`value\`='https://${PROJECT_DOMAIN}/' WHERE \`context_key\`='en' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${PROJECT_DOMAIN}/fr/' WHERE \`context_key\`='fr' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${PROJECT_DOMAIN}/es/' WHERE \`context_key\`='es' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${PROJECT_DOMAIN}/pdf/' WHERE \`context_key\`='pdf' AND \`key\`='site_url';
EOF

            echo "${COLOUR_CYAN}-- importing db_changepaths.sql...${COLOUR_RESTORE}"
            mysql -u${YAM_DATABASE_USER}_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${PROJECT_OWNER}_$PROJECT_NAME < /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/db_changepaths.sql

            # Delete any session data from previous database
            mysql -u${YAM_DATABASE_USER}_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME} << EOF
truncate modx_session;
EOF

            # Clean up database
            echo "${COLOUR_CYAN}-- removing installation files...${COLOUR_RESTORE}"
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/${URL_DATABASE##*/}
            rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/db_changepaths.sql
            rm -rf /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/setup

            echo "${COLOUR_CYAN}-- Adding cron job for backups${COLOUR_RESTORE}"
            if [ -f /etc/cron.d/backup_local_${PROJECT_OWNER} ]; then
                echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_local_${NEW_USER} << EOF
30 2    * * *   root    /usr/local/bin/yam_backup_local.sh ${PROJECT_OWNER} >> /var/log/cron.log 2>&1

EOF
            fi
            if [ -f /etc/cron.d/backup_s3_${NEW_USER} ]; then
                echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_s3_${NEW_USER} << EOF
* 3    * * *   root    /usr/local/bin/yam_backup_s3.sh ${PROJECT_OWNER} ${YAM_SERVER_NAME} >> /var/log/cron.log 2>&1

EOF
            fi

            echo "${COLOUR_CYAN}-- Setting up log rotation ${COLOUR_RESTORE}"
            if [ -f /etc/logrotate.d/${NEW_USER} ]; then
                echo "${COLOUR_CYAN}-- Log rotation already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/logrotate.d/${NEW_USER} << EOF
/home/${NEW_USER}/logs/nginx/*.log {
daily
missingok
rotate 7
compress
size 5M
notifempty
create 0640 www-data www-data
sharedscripts
}
EOF

            # Set permissions, just incase...
            echo "${COLOUR_CYAN}-- adjusting permissions...${COLOUR_RESTORE}"
            rm -rf /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/cache
            chown -R ${PROJECT_OWNER}:${PROJECT_OWNER} /home/${PROJECT_OWNER}/public/${PROJECT_NAME}

        # if a development website does not exist...
        else
            echo "A development website does not exist with the credentials given."
            echo "Please setup a new development website first and run this"
            echo "process again."
            exit
        fi

    else
        break
    fi
}

# Load package basesite function
packageWebsite() {
    if ask "Are you sure you want to package up a website?"; then
        read -p "Which project do you want to package? : " PROJECT_NAME
        read -p "Who owns the project? : " PROJECT_OWNER
        echo '------------------------------------------------------------------------'
        echo 'Packaging $PROJECT_NAME'
        echo '------------------------------------------------------------------------'

        if [ -d "/home/$PROJECT_OWNER/public/$PROJECT_NAME" ]; then

            # Creating tempory dir for files
            echo "${COLOUR_WHITE}>> creating temp folder...${COLOUR_RESTORE}"
            mkdir -p /home/${PROJECT_OWNER}/backup/temp/

            # Navigate to the desired project folder
            echo "${COLOUR_WHITE}>> packaging packages...${COLOUR_RESTORE}"
            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core
            zip -r /home/${PROJECT_OWNER}/backup/temp/packages.zip packages

            echo "${COLOUR_WHITE}>> packaging components...${COLOUR_RESTORE}"
            zip -r /home/${PROJECT_OWNER}/backup/temp/components.zip components

            echo "${COLOUR_WHITE}>> packaging assets...${COLOUR_RESTORE}"
            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}
            zip -r /home/${PROJECT_OWNER}/backup/temp/assets.zip assets

            echo "${COLOUR_WHITE}>> dumping database...${COLOUR_RESTORE}"
            mysqldump -u root ${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME} > /home/${PROJECT_OWNER}/backup/temp/${YAM_DATABASE_DB}_${PROJECT_OWNER}_${PROJECT_NAME}.sql

            # If backup folder for user exists skip, else create a folder called backup
            echo "${COLOUR_WHITE}>> checking if destination folder exists...${COLOUR_RESTORE}"
            if [ -d "/home/$PROJECT_OWNER/backup/$PROJECT_NAME" ]; then
                echo "-- Backup folder for ${PROJECT_NAME} already exists. Skipping..."
            else
                # Make backup dir for user
                mkdir -p /home/${PROJECT_OWNER}/backup/${PROJECT_NAME}
            fi

            echo "${COLOUR_WHITE}>> creating final package...${COLOUR_RESTORE}"
            cd /home/${PROJECT_OWNER}/backup/temp
            zip -r /home/${PROJECT_OWNER}/backup/${PROJECT_NAME}/${PROJECT_OWNER}-${PROJECT_NAME}-package-${YAM_DATEFORMAT_FULL}.zip .

            rm -rf /home/${PROJECT_OWNER}/backup/temp

            echo "${COLOUR_WHITE}Package complete: ${COLOUR_RESTORE}"
            echo "${COLOUR_WHITE}/home/${PROJECT_OWNER}/backup/${PROJECT_NAME}/${PROJECT_OWNER}-${PROJECT_NAME}-package-${YAM_DATEFORMAT_FULL}.zip ${COLOUR_RESTORE}"

        else
            echo "A development website does not exist with the credentials given."
            echo "Please check the information you provided and try again."
            exit
        fi

    else
        break
    fi
}

# Load add virtual host function
addVirtualhost() {
    if ask "Are you sure you want to add a new development website?"; then
        read -p "Project name  : " PROJECT_NAME
        read -p "Project user  : " USER
        read -s -p "User password  : " USER_PASSWORD
        echo
        read -p "Project URL  : " PROJECT_DOMAIN
        read -s -p "Project MYSQL password  : " DB_PASSWORD
        echo
        read -s -p "Root MYSQL password  : " DB_PASSWORD_ROOT
        echo
        echo '------------------------------------------------------------------------'
        echo 'Setting up virtual host'
        echo '------------------------------------------------------------------------'

        # if a user and project already exists...
        if [ -d "/home/${USER}/public/${PROJECT_NAME}" ]; then

            echo "A development website with these credentials already exists."
            echo "Please check the information you provided and try again."
            exit

        else

            # Add user to server
            echo "${COLOUR_WHITE}>> Checking user account for ${USER}...${COLOUR_RESTORE}"
            if id "$USER" >/dev/null 2>&1; then
                  echo "${COLOUR_CYAN}-- The user already exists. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- Adding user${COLOUR_RESTORE}"
                adduser --disabled-password --gecos "" ${USER}
                PASSWORD=$(mkpasswd ${USER_PASSWORD})
                usermod --password ${PASSWORD} ${USER}
                chown root:root /home/$USER

                echo "${COLOUR_CYAN}-- Setting up log rotation ${COLOUR_RESTORE}"
                if [ -f /etc/logrotate.d/${USER} ]; then
                    echo "${COLOUR_CYAN}-- Log rotation already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/logrotate.d/${USER} << EOF
/home/${USER}/logs/nginx/*.log {
    daily
    missingok
    rotate 7
    compress
    size 5M
    notifempty
    create 0640 www-data www-data
    sharedscripts
}
EOF
                fi

                echo "${COLOUR_CYAN}-- Adding cron job for backups${COLOUR_RESTORE}"

                if [ -f /etc/cron.d/backup_local_${USER} ]; then
                    echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_local_${USER} << EOF
30 2    * * *   root    /usr/local/bin/yam_backup_local.sh ${USER} >> /var/log/cron.log 2>&1

EOF
                fi

                if [ -f /etc/cron.d/backup_s3_${USER} ]; then
                    echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_s3_${USER} << EOF
* 3    * * *   root    /usr/local/bin/yam_backup_s3.sh ${USER} ${YAM_SERVER_NAME} >> /var/log/cron.log 2>&1

EOF
                fi

                echo "${COLOUR_CYAN}-- Setting up SFTP${COLOUR_RESTORE}"
                if grep -Fxq "Match User $USER" /etc/ssh/sshd_config
                then
                    echo "${COLOUR_CYAN}---- SFTP user found. Skipping...${COLOUR_RESTORE}"
                else
                    echo "${COLOUR_CYAN}---- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
                cat >> /etc/ssh/sshd_config << EOF

Match User ${USER}
    ChrootDirectory %h
    PasswordAuthentication yes
    ForceCommand internal-sftp
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
                service ssh restart
                fi

            fi

            # Create user directories
            echo "${COLOUR_WHITE}>> Creating home folder for ${USER}...${COLOUR_RESTORE}"
            mkdir -p /home/${USER}/public/${PROJECT_NAME}
            touch /home/${USER}/public/${PROJECT_NAME}/.nobackup
            chown -R ${USER}:${USER} /home/${USER}/public/${PROJECT_NAME}

            # Create session folder
            mkdir -p /home/${USER}/tmp/${PROJECT_NAME}
            chown -R ${USER}:${USER} /home/${USER}/tmp

            # Password protect directory by default
            if [ -f "/home/$USER/.htpasswd" ]; then
                echo "${COLOUR_CYAN}-- .htpassword file exists. adding user.${COLOUR_RESTORE}"
                htpasswd -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
            else
                echo "${COLOUR_CYAN}-- .htpassword does not exist. creating file and adding user.${COLOUR_RESTORE}"
                htpasswd -c -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
            fi

            # Create log files
            if [ -f "/home/$USER/logs/nginx/${USER}_${PROJECT_NAME}_error.log" ]; then
                echo "${COLOUR_CYAN}-- Log files for ${PROJECT_NAME} already exist. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- Creating log files${COLOUR_RESTORE}"
                touch /home/${USER}/logs/nginx/${USER}_${PROJECT_NAME}_error.log
            fi

            # Configure SSL
            echo "${COLOUR_WHITE}>> Configuring SSL...${COLOUR_RESTORE}"
            certbot -n --nginx certonly -d ${PROJECT_DOMAIN}

            echo "${COLOUR_WHITE}>> Configuring NGINX${COLOUR_RESTORE}"
            # Adding virtual host for user
            echo "${COLOUR_CYAN}-- Adding default conf file for $PROJECT_NAME...${COLOUR_RESTORE}"
            cat > /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email $YAM_EMAIL_BUG

# /nginx/conf.d/${USER}-${PROJECT_NAME}.conf

# dev url https
server {
    server_name ${PROJECT_DOMAIN};
    include /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${PROJECT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PROJECT_DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# dev url redirect http to https
server {
    server_name ${PROJECT_DOMAIN};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}
EOF

            # Adding conf file and directory for default website
            echo "${COLOUR_CYAN}-- Adding conf files and directory for ${PROJECT_NAME} ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d
            cat > /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email $YAM_EMAIL_BUG

# /nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf

error_log           /home/$USER/logs/nginx/${USER}_${PROJECT_NAME}_error.log;

# custom headers file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/$PROJECT_NAME.location.header.*.conf;

# location of web root
root /home/$USER/public/$PROJECT_NAME;
index index.php index.htm index.html;

# setup php to use FPM
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm-${USER}-${PROJECT_NAME}.sock;
    fastcgi_read_timeout 240;
}

# custom body file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/$PROJECT_NAME.location.body.*.conf;

# prevent access to hidden files
location ~ /\. {
    deny all;
}

# protect configuration folder
location ^~ /core {
	return 404;
}

# stop favicon generating 404
location = /favicon.ico {
    log_not_found off;
}

# custom cache file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/$PROJECT_NAME.location.footer.*.conf;

# setup FURL for MODX
location / {
    include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/$PROJECT_NAME.location.*.conf;
    #try to get file directly, try it as a directory or fall back to modx
    try_files \$uri \$uri/ @modx;
}

location @modx {
    #including ? in second rewrite argument causes nginx to drop GET params, so append them again
    rewrite ^/(.*)$ /index.php?q=\$1&\$args;
}

EOF

            # Adding custom conf directory for default website
            echo "${COLOUR_CYAN}-- Adding custom conf directory for $PROJECT_NAME ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d
            cat > /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/readme.txt << EOF
In this directory you can add custom rewrite rules in the follwing format.

$PROJECT_NAME.location.*.conf
This line adds rules into the location block which powers FURL for MODX

$PROJECT_NAME.location.header.*.conf
Add rules towards the top of the conf doc

$PROJECT_NAME.location.body.*.conf
Add rules towards the middle of the conf doc

$PROJECT_NAME.location.footer.*.conf
Add rules towards the footer of the conf doc

Don't forget to reload NGINX from the terminal using:
systemctl reload nginx
EOF
            # Add file to password protect directory by default
            cat > /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/${PROJECT_NAME}.location.password.conf << EOF
# add password directory
auth_basic "Private";
auth_basic_user_file /home/${USER}/.htpasswd;
EOF

            systemctl reload nginx
            echo ">> NGINX configuration complete."

            echo "${COLOUR_WHITE}>> Configuring php...${COLOUR_RESTORE}"
            if [ -f /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf ]; then
                echo "${COLOUR_CYAN}-- Pool configuration for ${USER}-${PROJECT_NAME} already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf << EOF
[${USER}-${PROJECT_NAME}]
user = ${USER}
group = ${USER}
listen = /var/run/php/php7.1-fpm-${USER}-${PROJECT_NAME}.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_value[session.save_path] = /home/${USER}/tmp/${PROJECT_NAME}
php_value[date.timezone] = ${YAM_DATEFORMAT_TIMEZONE}
php_value[cgi.fix_pathinfo] = 0
php_value[memory_limit] = 256M
php_value[upload_max_filesize] = 100M
php_value[default_socket_timeout] = 120
php_value[session.cookie_secure] = 1
php_value[session.cookie_httponly] = 1
EOF
                systemctl restart php7.1-fpm
                echo "${COLOUR_CYAN}-- Added php worker for ${USER}-${PROJECT_NAME} ${COLOUR_RESTORE}"
            fi

            # Create database and user
            echo "${COLOUR_WHITE}>> Setting up database...${COLOUR_RESTORE}"
            mysql --user=root --password=$DB_PASSWORD_ROOT << EOF
CREATE DATABASE IF NOT EXISTS ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME};
CREATE USER '${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME}.* TO '${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME}'@'localhost';
FLUSH PRIVILEGES;
EOF

        fi

    else
        break
    fi
}

# Load add virtual host with basesite function
addVirtualhostBasesite() {
    if ask "Are you sure you want to setup a new Virtual Host with Basesite installed?"; then
        read -p "Project name  : " PROJECT_NAME
        read -p "Project user  : " USER
        read -s -p "User password  : " PASSWORD_USER
        echo
        read -p "Project URL  : " DOMAIN_TEST
        read -s -p "Project MYSQL password  : " PASSWORD_MYSQL_USER
        echo
        read -s -p "Root MYSQL password  : " PASSWORD_MYSQL_ROOT
        echo
        echo '------------------------------------------------------------------------'
        echo 'Setting up virtual host with Basesite'
        echo '------------------------------------------------------------------------'

        # if a user and project already exists...
        if [ -d "/home/${USER}/public/${PROJECT_NAME}" ]; then

            echo "A development website with these credentials already exists."
            echo "Please check the information you provided and try again."
            exit

        else

            # Add user to server
            echo "${COLOUR_WHITE}>> Checking user account for ${USER}...${COLOUR_RESTORE}"
            if id "$USER" >/dev/null 2>&1; then
                  echo "-- The user already exists. Skipping..."
            else
                adduser --disabled-password --gecos "" ${USER}
                PASSWORD=$(mkpasswd ${PASSWORD_USER})
                usermod --password ${PASSWORD} ${USER}
                chown root:root /home/${USER}

                echo "${COLOUR_CYAN}-- Added user ${COLOUR_RESTORE}"

                echo "${COLOUR_CYAN}-- Setting up log rotation ${COLOUR_RESTORE}"
                if [ -f /etc/logrotate.d/$USER ]; then
                    echo "${COLOUR_CYAN}---- Log rotation already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/logrotate.d/${USER} << EOF
/home/${USER}/logs/nginx/*.log {
    daily
    missingok
    rotate 7
    compress
    size 5M
    notifempty
    create 0640 www-data www-data
    sharedscripts
}
EOF
                fi

                echo "${COLOUR_CYAN}-- Adding cron job for backups${COLOUR_RESTORE}"

                if [ -f /etc/cron.d/backup_local_$USER ]; then
                    echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_local_$USER << EOF
30 2    * * *   root    /usr/local/bin/yam_backup_local.sh $USER >> /var/log/cron.log 2>&1

EOF
                fi

                if [ -f /etc/cron.d/backup_s3_$USER ]; then
                    echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_s3_$USER << EOF
* 3    * * *   root    /usr/local/bin/yam_backup_s3.sh $USER $YAM_SERVER_NAME >> /var/log/cron.log 2>&1

EOF
                fi

                echo "${COLOUR_CYAN}-- Setting up SFTP${COLOUR_RESTORE}"
                if grep -Fxq "Match User $USER" /etc/ssh/sshd_config
                then
                    echo "${COLOUR_CYAN}---- SFTP user found. Skipping...${COLOUR_RESTORE}"
                else
                    echo "${COLOUR_CYAN}---- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
                cat >> /etc/ssh/sshd_config  << EOF

Match User ${USER}
    ChrootDirectory %h
    PasswordAuthentication yes
    ForceCommand internal-sftp
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
                service ssh restart

                fi

            fi

            # Create user directories
            echo "${COLOUR_WHITE}>> Creating project folder for ${USER}...${COLOUR_RESTORE}"
            mkdir -p /home/${USER}/public/${PROJECT_NAME}
            touch /home/${USER}/public/${PROJECT_NAME}/.nobackup

            # Create sessions folder
            mkdir -p /home/${USER}/tmp/${PROJECT_NAME}
            chown -R ${USER}:${USER} /home/${USER}/tmp

            # Installing Basesite
            echo "${COLOUR_WHITE}>> Installing Basesite ${USER}...${COLOUR_RESTORE}"

            echo "${COLOUR_CYAN}-- Copying Basesite from base to ${PROJECT_NAME} ${COLOUR_RESTORE}"
            cp -R ${YAM_BASESITE_PATH}. /home/${USER}/public/${PROJECT_NAME}

            echo "${COLOUR_CYAN}-- Deleting existing config files in core, manager and connectors... ${COLOUR_RESTORE}"
            rm /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php
            rm /home/${USER}/public/${PROJECT_NAME}/connectors/config.core.php
            rm /home/${USER}/public/${PROJECT_NAME}/manager/config.core.php
            rm /home/${USER}/public/${PROJECT_NAME}/config.core.php

            echo "${COLOUR_CYAN}-- Deleting cache folder${COLOUR_RESTORE}"
            rm -rf /home/${USER}/public/${PROJECT_NAME}/core/cache/

            echo "${COLOUR_WHITE}>> Installing MODX config files...${COLOUR_RESTORE}"

            # Add core config for MODX
            cat > /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = '${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME}';
\$database_password = '${PASSWORD_MYSQL_USER}';
\$database_connection_charset = 'utf8';
\$dbase = '${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME};charset=utf8';
\$config_options = array (
);
\$driver_options = array (
);

\$lastInstallTime = 1526050719;

\$site_id = '${USER}${PROJECT_NAME}modx5af5af9faea5b6.77147055';
\$site_sessionname = '${USER}${PROJECT_NAME}SN5af5af09710f3';
\$https_port = '443';
\$uuid = '2c109d9c-4d41-4b8b-a961-84457ae83978';

if (!defined('MODX_CORE_PATH')) {
    \$modx_core_path= '/home/${USER}/public/${PROJECT_NAME}/core/';
    define('MODX_CORE_PATH', \$modx_core_path);
}
if (!defined('MODX_PROCESSORS_PATH')) {
    \$modx_processors_path= '/home/${USER}/public/${PROJECT_NAME}/core/model/modx/processors/';
    define('MODX_PROCESSORS_PATH', \$modx_processors_path);
}
if (!defined('MODX_CONNECTORS_PATH')) {
    \$modx_connectors_path= '/home/${USER}/public/${PROJECT_NAME}/connectors/';
    \$modx_connectors_url= '/connectors/';
    define('MODX_CONNECTORS_PATH', \$modx_connectors_path);
    define('MODX_CONNECTORS_URL', \$modx_connectors_url);
}
if (!defined('MODX_MANAGER_PATH')) {
    \$modx_manager_path= '/home/${USER}/public/${PROJECT_NAME}/manager/';
    \$modx_manager_url= '/manager/';
    define('MODX_MANAGER_PATH', \$modx_manager_path);
    define('MODX_MANAGER_URL', \$modx_manager_url);
}
if (!defined('MODX_BASE_PATH')) {
    \$modx_base_path= '/home/${USER}/public/${PROJECT_NAME}/';
    \$modx_base_url= '/';
    define('MODX_BASE_PATH', \$modx_base_path);
    define('MODX_BASE_URL', \$modx_base_url);
}
if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
    \$isSecureRequest = false;
} else {
    \$isSecureRequest = ((isset (\$_SERVER['HTTPS']) && strtolower(\$_SERVER['HTTPS']) == 'on') || \$_SERVER['SERVER_PORT'] == \$https_port);
}
if (!defined('MODX_URL_SCHEME')) {
    \$url_scheme=  \$isSecureRequest ? 'https://' : 'http://';
    define('MODX_URL_SCHEME', \$url_scheme);
}
if (!defined('MODX_HTTP_HOST')) {
    if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
        \$http_host='localhost';
        define('MODX_HTTP_HOST', \$http_host);
    } else {
        \$http_host= array_key_exists('HTTP_HOST', \$_SERVER) ? htmlspecialchars(\$_SERVER['HTTP_HOST'], ENT_QUOTES) : 'localhost';
        if (\$_SERVER['SERVER_PORT'] != 80) {
            \$http_host= str_replace(':' . \$_SERVER['SERVER_PORT'], '', \$http_host); // remove port from HTTP_HOST
        }
        \$http_host .= (\$_SERVER['SERVER_PORT'] == 80 || \$isSecureRequest) ? '' : ':' . \$_SERVER['SERVER_PORT'];
        define('MODX_HTTP_HOST', \$http_host);
    }
}
if (!defined('MODX_SITE_URL')) {
    \$site_url= \$url_scheme . \$http_host . MODX_BASE_URL;
    define('MODX_SITE_URL', \$site_url);
}
if (!defined('MODX_ASSETS_PATH')) {
    \$modx_assets_path= '/home/${USER}/public/${PROJECT_NAME}/assets/';
    \$modx_assets_url= '/assets/';
    define('MODX_ASSETS_PATH', \$modx_assets_path);
    define('MODX_ASSETS_URL', \$modx_assets_url);
}
if (!defined('MODX_LOG_LEVEL_FATAL')) {
    define('MODX_LOG_LEVEL_FATAL', 0);
    define('MODX_LOG_LEVEL_ERROR', 1);
    define('MODX_LOG_LEVEL_WARN', 2);
    define('MODX_LOG_LEVEL_INFO', 3);
    define('MODX_LOG_LEVEL_DEBUG', 4);
}
if (!defined('MODX_CACHE_DISABLED')) {
    \$modx_cache_disabled= false;
    define('MODX_CACHE_DISABLED', \$modx_cache_disabled);
}
EOF
            # Add manager config for MODX
            cat > /home/${USER}/public/${PROJECT_NAME}/manager/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${USER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Add connectors config for MODX
            cat > /home/${USER}/public/${PROJECT_NAME}/connectors/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${USER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Add root config for MODX
            cat > /home/${USER}/public/${PROJECT_NAME}/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${USER}/public/${PROJECT_NAME}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Secure / change permissions on config file after save
            echo "${COLOUR_CYAN}-- Adjusting permissions...${COLOUR_RESTORE}"
            chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php
            chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/manager/config.core.php
            chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/connectors/config.core.php
            chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/config.core.php

            # Change permissions
            chown -R ${USER}:${USER} /home/${USER}/public/${PROJECT_NAME}

            # Password protect directory by default
            echo "${COLOUR_CYAN}-- Password protecting directory...${COLOUR_RESTORE}"
            if [ -f "/home/$USER/.htpasswd" ]; then
                echo "${COLOUR_CYAN}-- .htpassword file exists. adding user.${COLOUR_RESTORE}"
                htpasswd -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
            else
                echo "${COLOUR_CYAN}-- .htpassword file does not exist. creating file and adding user.${COLOUR_RESTORE}"
                htpasswd -c -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
            fi

            # Create log files
            echo "${COLOUR_WHITE}>> Creating log files...${COLOUR_RESTORE}"
            if [ -e "/home/$USER/logs/nginx/${USER}_${PROJECT_NAME}_error.log" ]; then
                echo "${COLOUR_CYAN}-- Log files for ${PROJECT_NAME} already exist. Skipping...${COLOUR_RESTORE}"
            else
                touch /home/${USER}/logs/nginx/${USER}_${PROJECT_NAME}_error.log
            fi

            # Configure SSL
            echo "${COLOUR_WHITE}>> Configuring SSL...${COLOUR_RESTORE}"
            certbot -n --nginx certonly -d ${DOMAIN_TEST}

            echo "${COLOUR_WHITE}>> Configuring NGINX${COLOUR_RESTORE}"
            # Adding virtual host for user
            echo "${COLOUR_CYAN}-- Adding default conf file for ${PROJECT_NAME}...${COLOUR_RESTORE}"
            cat > /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/${USER}-${PROJECT_NAME}.conf

# dev url https
server {
    server_name ${DOMAIN_TEST};
    include /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_TEST}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_TEST}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# dev url redirect http to https
server {
    server_name ${DOMAIN_TEST};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}
EOF

            # Adding conf file and directory for default website
            echo "${COLOUR_CYAN}-- Adding conf files and directory for $PROJECT_NAME ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d
            cat > /etc/nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/${USER}-${PROJECT_NAME}.d/main.conf

error_log           /home/$USER/logs/nginx/${USER}_${PROJECT_NAME}_error.log;

# custom headers file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/$PROJECT_NAME.location.header.*.conf;

# location of web root
root /home/${USER}/public/${PROJECT_NAME};
index index.php index.htm index.html;

# setup php to use FPM
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm-${USER}-${PROJECT_NAME}.sock;
    fastcgi_read_timeout 240;
}

# custom body file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/${PROJECT_NAME}.location.body.*.conf;

# prevent access to hidden files
location ~ /\. {
    deny all;
}

# protect configuration folder
location ^~ /core {
    return 404;
}

# stop favicon generating 404
location = /favicon.ico {
    log_not_found off;
}

# custom cache file loads here if included
include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/${PROJECT_NAME}.location.footer.*.conf;

# setup FURL for MODX
location / {
    include /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/${PROJECT_NAME}.location.*.conf;
    #try to get file directly, try it as a directory or fall back to modx
    try_files \$uri \$uri/ @modx;
}

location @modx {
    #including ? in second rewrite argument causes nginx to drop GET params, so append them again
    rewrite ^/(.*)$ /index.php?q=\$1&\$args;
}

EOF

            # Adding custom conf directory for project
            echo "${COLOUR_CYAN}-- Adding custom conf directory for ${PROJECT_NAME} ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d
            cat > /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/readme.txt << EOF
In this directory you can add custom rewrite rules in the follwing format.

${PROJECT_NAME}.location.*.conf
This line adds rules into the location block which powers FURL for MODX

${PROJECT_NAME}.location.header.*.conf
Add rules towards the top of the conf doc

${PROJECT_NAME}.location.body.*.conf
Add rules towards the middle of the conf doc

${PROJECT_NAME}.location.footer.*.conf
Add rules towards the footer of the conf doc

Don't forget to reload NGINX from the terminal using:
systemctl reload nginx
EOF
        # Add file to password protect directory by default
        cat > /etc/nginx/custom.d/${USER}-${PROJECT_NAME}.d/${PROJECT_NAME}.location.password.conf << EOF
# add password directory
auth_basic "Private";
auth_basic_user_file /home/${USER}/.htpasswd;
EOF

            systemctl reload nginx

            echo "${COLOUR_WHITE}>> Configuring php...${COLOUR_RESTORE}"
            if [ -f /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf ]; then
                echo "${COLOUR_CYAN}-- Pool configuration for ${PROJECT_NAME} already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf << EOF
[${USER}-${PROJECT_NAME}]
user = ${USER}
group = ${USER}
listen = /var/run/php/php7.1-fpm-${USER}-${PROJECT_NAME}.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_value[session.save_path] = /home/${USER}/tmp/${PROJECT_NAME}
php_value[date.timezone] = ${YAM_DATEFORMAT_TIMEZONE}
php_value[cgi.fix_pathinfo] = 0
php_value[memory_limit] = 256M
php_value[upload_max_filesize] = 100M
php_value[default_socket_timeout] = 120
php_value[session.cookie_secure] = 1
php_value[session.cookie_httponly] = 1
EOF
                systemctl restart php7.1-fpm
                echo "${COLOUR_CYAN}-- Added php worker for ${USER}-${PROJECT_NAME}.${COLOUR_RESTORE}"
            fi

            # Create database and user
            echo "${COLOUR_WHITE}>> Setting up database...${COLOUR_RESTORE}"
            mysql --user=root --password=${PASSWORD_MYSQL_ROOT} << EOF
CREATE DATABASE IF NOT EXISTS ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME};
CREATE USER '${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME}'@'localhost' IDENTIFIED BY '${PASSWORD_MYSQL_USER}';
GRANT ALL PRIVILEGES ON ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME}.* TO '${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME}'@'localhost';
FLUSH PRIVILEGES;
EOF
            # Copy Basesite db and import into new project
            echo "${COLOUR_CYAN}-- Injecting Basesite into database...${COLOUR_RESTORE}"
            # Export
            mysqldump -u root ${YAM_BASESITE_DB} > /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql
            # Import
            mysql -u ${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME} -p${PASSWORD_MYSQL_USER} ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME} < /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql

            # Changing paths in db
            echo "${COLOUR_CYAN}-- Exporting db_changepaths.sql...${COLOUR_RESTORE}"
            cat > /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql << EOF
UPDATE \`modx_context_setting\` SET \`value\`='${DOMAIN_TEST}' WHERE \`context_key\`='en' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${DOMAIN_TEST}' WHERE \`context_key\`='fr' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${DOMAIN_TEST}' WHERE \`context_key\`='es' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${DOMAIN_TEST}' WHERE \`context_key\`='pdf' AND \`key\`='http_host';

UPDATE \`modx_context_setting\` SET \`value\`='https://${DOMAIN_TEST}/' WHERE \`context_key\`='en' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${DOMAIN_TEST}/fr/' WHERE \`context_key\`='fr' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${DOMAIN_TEST}/es/' WHERE \`context_key\`='es' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${DOMAIN_TEST}/pdf/' WHERE \`context_key\`='pdf' AND \`key\`='site_url';
EOF

            echo "${COLOUR_CYAN}-- Importing db_changepaths.sql...${COLOUR_RESTORE}"
            mysql -u ${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME} -p$PASSWORD_MYSQL_USER ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME} < /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql

            # Delete any session data from previous database
            mysql -u ${YAM_DATABASE_USER}_${USER}_${PROJECT_NAME} -p${PASSWORD_MYSQL_USER} ${YAM_DATABASE_DB}_${USER}_${PROJECT_NAME} << EOF
truncate modx_session;
EOF

            # Clean up database
            echo "${COLOUR_CYAN}-- Removing database installation files...${COLOUR_RESTORE}"
            rm /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql
            rm /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql

            echo "Installation complete."

        fi

    else
        break
    fi
}

# Load copy virtual host fucnction
copyVirtualhost() {
    if ask "Are you sure you want to copy a development website?"; then
        read -p "Copy project  : " COPY_PROJECT
        read -p "Copy project user  : " COPY_USER
        read -p "New project  : " NEW_PROJECT
        read -p "New project user  : " NEW_USER
        read -s -p "New project user password  : " NEW_PASSWORD_OWNER
        echo
        read -s -p "New project MYSQL password  : " NEW_PASSWORD_MYSQL
        echo
        read -p "New URL  : " NEW_URL
        echo '------------------------------------------------------------------------'
        echo 'Copying project...'
        echo '------------------------------------------------------------------------'

        # if a user and project already exists...
        if [ -d "/home/${COPY_USER}/public/${COPY_PROJECT}" ]; then

            # Add user to server if it doesn't exist
            echo "${COLOUR_WHITE}>> Checking user account for ${NEW_USER}...${COLOUR_RESTORE}"
            if id "${NEW_USER}" >/dev/null 2>&1; then
                  echo "-- The user already exists. Skipping..."
            else
                adduser --disabled-password --gecos "" ${NEW_USER}
                PASSWORD=$(mkpasswd ${NEW_PASSWORD_OWNER})
                usermod --password ${PASSWORD} ${NEW_USER}
                chown root:root /home/${USER}

                echo "${COLOUR_CYAN}-- Added new user ${COLOUR_RESTORE}"

                echo "${COLOUR_CYAN}-- Setting up log rotation ${COLOUR_RESTORE}"
                if [ -f /etc/logrotate.d/${NEW_USER} ]; then
                    echo "${COLOUR_CYAN}-- Log rotation already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/logrotate.d/${NEW_USER} << EOF
/home/${NEW_USER}/logs/nginx/*.log {
    daily
    missingok
    rotate 7
    compress
    size 5M
    notifempty
    create 0640 www-data www-data
    sharedscripts
}
EOF
                fi

                echo "${COLOUR_CYAN}-- Adding cron job for backups${COLOUR_RESTORE}"
                if [ -f /etc/cron.d/backup_local_${NEW_USER} ]; then
                    echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_local_${NEW_USER} << EOF
30 2    * * *   root    /usr/local/bin/yam_backup_local.sh ${NEW_USER} >> /var/log/cron.log 2>&1

EOF
                fi
                if [ -f /etc/cron.d/backup_s3_${NEW_USER} ]; then
                    echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
                else
                    cat > /etc/cron.d/backup_s3_${NEW_USER} << EOF
* 3    * * *   root    /usr/local/bin/yam_backup_s3.sh ${NEW_USER} ${YAM_SERVER_NAME} >> /var/log/cron.log 2>&1

EOF
                fi

                echo "${COLOUR_CYAN}-- Setting up SFTP${COLOUR_RESTORE}"
                if grep -Fxq "Match User ${NEW_OWNER}" /etc/ssh/sshd_config
                then
                    echo "${COLOUR_CYAN}---- SFTP user found. Skipping...${COLOUR_RESTORE}"
                else
                    echo "${COLOUR_CYAN}---- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
                cat >> /etc/ssh/sshd_config  << EOF

Match User ${NEW_USER}
    ChrootDirectory %h
    PasswordAuthentication yes
    ForceCommand internal-sftp
    PermitTunnel no
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
                service ssh restart

                fi

            fi

            # Create project folder
            echo "${COLOUR_WHITE}>> Creating project folder for ${NEW_USER}...${COLOUR_RESTORE}"
            mkdir -p /home/${NEW_USER}/public/${NEW_PROJECT}

            # Create new session folder
            mkdir -p /home/${NEW_USER}/tmp/${NEW_PROJECT}
            chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/tmp/${NEW_PROJECT}

            # Copy project a to b
            echo "${COLOUR_WHITE}>> Copying ${COPY_PROJECT} owned by ${COPY_USER} to ${NEW_PROJECT} owned by ${NEW_USER}...${COLOUR_RESTORE}"
            cp -R /home/${COPY_USER}/public/${COPY_PROJECT}/. /home/${NEW_USER}/public/${NEW_PROJECT}
            touch /home/${NEW_USER}/public/${NEW_PROJECT}/.nobackup

            # Password protect directory by default
            echo "${COLOUR_WHITE}>> Password protecting directory...${COLOUR_RESTORE}"
            if [ -f "/home/${NEW_USER}/.htpasswd" ]; then
                echo "${COLOUR_CYAN}-- .htpassword file exists. adding user.${COLOUR_RESTORE}"
                htpasswd -b /home/${NEW_USER}/.htpasswd ${NEW_PROJECT} ${YAM_PASSWORD_GENERIC}
            else
                echo "${COLOUR_CYAN}-- .htpassword file does not exist. creating file and adding user.${COLOUR_RESTORE}"
                htpasswd -c -b /home/${NEW_USER}/.htpasswd ${NEW_PROJECT} ${YAM_PASSWORD_GENERIC}
            fi

            # Configure SSL
            echo "${COLOUR_WHITE}>> Configuring SSL...${COLOUR_RESTORE}"
            certbot -n --nginx certonly -d ${NEW_URL}

            echo "${COLOUR_WHITE}>> Configuring NGINX${COLOUR_RESTORE}"
            # Adding virtual host for user
            echo "${COLOUR_CYAN}-- Adding default conf file for ${NEW_PROJECT}...${COLOUR_RESTORE}"
            cat > /etc/nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email $YAM_EMAIL_BUG

# /nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.conf

# dev url https
server {
    server_name ${NEW_URL};
    include /etc/nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${NEW_URL}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${NEW_URL}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# dev url redirect http to https
server {
    server_name ${NEW_URL};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}
EOF

            # Adding conf file and directory for default website
            echo "${COLOUR_CYAN}-- Adding conf files and directory for ${NEW_PROJECT} ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.d
            cat > /etc/nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.d/main.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email $YAM_EMAIL_BUG

# /nginx/conf.d/${NEW_USER}-${NEW_PROJECT}.d/main.conf

error_log           /home/${NEW_USER}/logs/nginx/${NEW_USER}_${NEW_PROJECT}_error.log;

# custom headers file loads here if included
include /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/${NEW_PROJECT}.location.header.*.conf;

# location of web root
root /home/${NEW_USER}/public/${NEW_PROJECT};
index index.php index.htm index.html;

# setup php to use FPM
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm-${NEW_USER}-${NEW_PROJECT}.sock;
    fastcgi_read_timeout 240;
}

# custom body file loads here if included
include /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/${NEW_PROJECT}.location.body.*.conf;

# prevent access to hidden files
location ~ /\. {
    deny all;
}

# protect configuration folder
location ^~ /core {
    return 404;
}

# stop favicon generating 404
location = /favicon.ico {
    log_not_found off;
}

# custom cache file loads here if included
include /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/${NEW_PROJECT}.location.footer.*.conf;

# setup FURL for MODX
location / {
    include /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/${NEW_PROJECT}.location.*.conf;
    #try to get file directly, try it as a directory or fall back to modx
    try_files \$uri \$uri/ @modx;
}

location @modx {
    #including ? in second rewrite argument causes nginx to drop GET params, so append them again
    rewrite ^/(.*)$ /index.php?q=\$1&\$args;
}

EOF

            # Adding custom conf directory for project
            echo "${COLOUR_CYAN}-- Adding custom conf directory for ${NEW_PROJECT} ${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d
            cat > /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/readme.txt << EOF
In this directory you can add custom rewrite rules in the follwing format.

${NEW_PROJECT}.location.*.conf
This line adds rules into the location block which powers FURL for MODX

${NEW_PROJECT}.location.header.*.conf
Add rules towards the top of the conf doc

${NEW_PROJECT}.location.body.*.conf
Add rules towards the middle of the conf doc

${NEW_PROJECT}.location.footer.*.conf
Add rules towards the footer of the conf doc

Don't forget to reload NGINX from the terminal using:
systemctl reload nginx
EOF
            # Add file to password protect directory by default
            cat > /etc/nginx/custom.d/${NEW_USER}-${NEW_PROJECT}.d/${NEW_PROJECT}.location.password.conf << EOF
# add password directory
auth_basic "Private";
auth_basic_user_file /home/${NEW_USER}/.htpasswd;
EOF

            systemctl reload nginx
            echo "${COLOUR_CYAN}-- NGINX configuration complete.${COLOUR_RESTORE}"

            echo "${COLOUR_WHITE}>> Configuring php...${COLOUR_RESTORE}"
            if [ -f /etc/php/7.1/fpm/pool.d/${NEW_USER}-${NEW_PROJECT}.conf ]; then
                echo "${COLOUR_CYAN}-- Pool configuration for ${NEW_PROJECT} already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/php/7.1/fpm/pool.d/${NEW_USER}-${NEW_PROJECT}.conf << EOF
[${NEW_USER}-${NEW_PROJECT}]
user = ${NEW_USER}
group = ${NEW_USER}
listen = /var/run/php/php7.1-fpm-${NEW_USER}-${NEW_PROJECT}.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_value[session.save_path] = /home/${NEW_USER}/tmp/${NEW_PROJECT}
php_value[date.timezone] = ${YAM_DATEFORMAT_TIMEZONE}
php_value[cgi.fix_pathinfo] = 0
php_value[memory_limit] = 256M
php_value[upload_max_filesize] = 100M
php_value[default_socket_timeout] = 120
php_value[session.cookie_secure] = 1
php_value[session.cookie_httponly] = 1
EOF
                systemctl restart php7.1-fpm
                echo "${COLOUR_CYAN}-- Added php worker for ${NEW_USER}-${NEW_PROJECT}.${COLOUR_RESTORE}"
            fi

            # Create database and user
            echo "${COLOUR_WHITE}>> Setting up new mysql user and database...${COLOUR_RESTORE}"
            mysql --user=root << EOF
CREATE DATABASE IF NOT EXISTS ${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT};
CREATE USER '${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT}'@'localhost' IDENTIFIED BY '${NEW_PASSWORD_MYSQL}';
GRANT ALL PRIVILEGES ON ${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT}.* TO '${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT}'@'localhost';
FLUSH PRIVILEGES;
EOF

            # Copy basesite db and import into new project
            echo "${COLOUR_WHITE}>> Installing database...${COLOUR_RESTORE}"
            # Export
            mysqldump -u root ${YAM_DATABASE_DB}_${COPY_USER}_${COPY_PROJECT} > /home/${NEW_USER}/public/${NEW_PROJECT}/${YAM_DATABASE_DB}_${COPY_USER}_${COPY_PROJECT}.sql
            # Import
            mysql -u ${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT} < /home/${NEW_USER}/public/${NEW_PROJECT}/${YAM_DATABASE_DB}_${COPY_USER}_${COPY_PROJECT}.sql

            # Changing paths in db
            echo "${COLOUR_CYAN}-- Exporting db_changepaths.sql...${COLOUR_RESTORE}"
            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/db_changepaths.sql << EOF
UPDATE \`modx_context_setting\` SET \`value\`='${NEW_URL}' WHERE \`context_key\`='en' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${NEW_URL}' WHERE \`context_key\`='fr' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${NEW_URL}' WHERE \`context_key\`='es' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${NEW_URL}' WHERE \`context_key\`='pdf' AND \`key\`='http_host';

UPDATE \`modx_context_setting\` SET \`value\`='https://${NEW_URL}/' WHERE \`context_key\`='en' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${NEW_URL}/fr/' WHERE \`context_key\`='fr' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${NEW_URL}/es/' WHERE \`context_key\`='es' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${NEW_URL}/pdf/' WHERE \`context_key\`='pdf' AND \`key\`='site_url';
EOF

            # Delete any session data from previous database
            echo "${COLOUR_CYAN}-- Deleting any session data from previous database...${COLOUR_RESTORE}"
            mysql -u ${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT} << EOF
truncate modx_session;
EOF

            echo "${COLOUR_CYAN}-- Importing db_changepaths.sql...${COLOUR_RESTORE}"
            mysql -u ${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} ${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT} < /home/${NEW_USER}/public/${NEW_PROJECT}/db_changepaths.sql

            # Clean up database
            echo "${COLOUR_CYAN}-- Removing database installation files...${COLOUR_RESTORE}"
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/${YAM_DATABASE_DB}_${COPY_USER}_${COPY_PROJECT}.sql
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/db_changepaths.sql

            # Delete config files and delete cache folder
            echo "${COLOUR_WHITE}>> Deleting existing config files in core, manager and connectors... ${COLOUR_RESTORE}"
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php
            rm /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php

            echo "${COLOUR_WHITE}>> Deleting cache folder${COLOUR_RESTORE}"
            rm -rf /home/${NEW_USER}/public/${NEW_PROJECT}/core/cache/

            # Add core config for MODX
            echo "${COLOUR_WHITE}>> Installing new config files...${COLOUR_RESTORE}"
            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = '${YAM_DATABASE_USER}_${NEW_USER}_${NEW_PROJECT}';
\$database_password = '${NEW_PASSWORD_MYSQL}';
\$database_connection_charset = 'utf8';
\$dbase = '${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=${YAM_DATABASE_DB}_${NEW_USER}_${NEW_PROJECT};charset=utf8';
\$config_options = array (
);
\$driver_options = array (
);

\$lastInstallTime = 1526050719;

\$site_id = '${NEW_USER}${NEW_PROJECT}modx5af5af9faea5b6.77147055';
\$site_sessionname = '${NEW_USER}${NEW_PROJECT}SN5af5af09710f3';
\$https_port = '443';
\$uuid = '2c109d9c-4d41-4b8b-a961-84457ae83978';

if (!defined('MODX_CORE_PATH')) {
    \$modx_core_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/core/';
    define('MODX_CORE_PATH', \$modx_core_path);
}
if (!defined('MODX_PROCESSORS_PATH')) {
    \$modx_processors_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/core/model/modx/processors/';
    define('MODX_PROCESSORS_PATH', \$modx_processors_path);
}
if (!defined('MODX_CONNECTORS_PATH')) {
    \$modx_connectors_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/connectors/';
    \$modx_connectors_url= '/connectors/';
    define('MODX_CONNECTORS_PATH', \$modx_connectors_path);
    define('MODX_CONNECTORS_URL', \$modx_connectors_url);
}
if (!defined('MODX_MANAGER_PATH')) {
    \$modx_manager_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/manager/';
    \$modx_manager_url= '/manager/';
    define('MODX_MANAGER_PATH', \$modx_manager_path);
    define('MODX_MANAGER_URL', \$modx_manager_url);
}
if (!defined('MODX_BASE_PATH')) {
    \$modx_base_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/';
    \$modx_base_url= '/';
    define('MODX_BASE_PATH', \$modx_base_path);
    define('MODX_BASE_URL', \$modx_base_url);
}
if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
    \$isSecureRequest = false;
} else {
    \$isSecureRequest = ((isset (\$_SERVER['HTTPS']) && strtolower(\$_SERVER['HTTPS']) == 'on') || \$_SERVER['SERVER_PORT'] == \$https_port);
}
if (!defined('MODX_URL_SCHEME')) {
    \$url_scheme=  \$isSecureRequest ? 'https://' : 'http://';
    define('MODX_URL_SCHEME', \$url_scheme);
}
if (!defined('MODX_HTTP_HOST')) {
    if(defined('PHP_SAPI') && (PHP_SAPI == "cli" || PHP_SAPI == "embed")) {
        \$http_host='localhost';
        define('MODX_HTTP_HOST', \$http_host);
    } else {
        \$http_host= array_key_exists('HTTP_HOST', \$_SERVER) ? htmlspecialchars(\$_SERVER['HTTP_HOST'], ENT_QUOTES) : 'localhost';
        if (\$_SERVER['SERVER_PORT'] != 80) {
            \$http_host= str_replace(':' . \$_SERVER['SERVER_PORT'], '', \$http_host); // remove port from HTTP_HOST
        }
        \$http_host .= (\$_SERVER['SERVER_PORT'] == 80 || \$isSecureRequest) ? '' : ':' . \$_SERVER['SERVER_PORT'];
        define('MODX_HTTP_HOST', \$http_host);
    }
}
if (!defined('MODX_SITE_URL')) {
    \$site_url= \$url_scheme . \$http_host . MODX_BASE_URL;
    define('MODX_SITE_URL', \$site_url);
}
if (!defined('MODX_ASSETS_PATH')) {
    \$modx_assets_path= '/home/${NEW_USER}/public/${NEW_PROJECT}/assets/';
    \$modx_assets_url= '/assets/';
    define('MODX_ASSETS_PATH', \$modx_assets_path);
    define('MODX_ASSETS_URL', \$modx_assets_url);
}
if (!defined('MODX_LOG_LEVEL_FATAL')) {
    define('MODX_LOG_LEVEL_FATAL', 0);
    define('MODX_LOG_LEVEL_ERROR', 1);
    define('MODX_LOG_LEVEL_WARN', 2);
    define('MODX_LOG_LEVEL_INFO', 3);
    define('MODX_LOG_LEVEL_DEBUG', 4);
}
if (!defined('MODX_CACHE_DISABLED')) {
    \$modx_cache_disabled= false;
    define('MODX_CACHE_DISABLED', \$modx_cache_disabled);
}
EOF

            # Add manager config for MODX
            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${NEW_USER}/public/${NEW_PROJECT}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Add connectors config for MODX
            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${NEW_USER}/public/${NEW_PROJECT}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php << EOF
<?php
/*
 * This file is managed by the installation process.  Any modifications to it may get overwritten.
 * Add customizations to the $config_options array in \`core/config/config.inc.php\`.
 *
 */
define('MODX_CORE_PATH', '/home/${NEW_USER}/public/${NEW_PROJECT}/core/');
define('MODX_CONFIG_KEY', 'config');
?>
EOF

            # Secure / change permissions on config file after save
            echo "${COLOUR_WHITE}>> Adjusting permissions...${COLOUR_RESTORE}"
            chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php
            chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php
            chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php
            chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php

            # Change permissions
            chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/public/${NEW_PROJECT}

            echo "${COLOUR_WHITE}Copy complete.${COLOUR_RESTORE}"

        else

            echo "/home/${COPY_USER}/public/${COPY_PROJECT} does not exist"
            echo "Please check the information you provided and try again."
            exit

        fi

    else
        break
    fi
}

# Map domain to website function
addDomain() {
    if ask "Are you sure you want to add a domain to a website?"; then
        read -p "Domain name  : " ADD_DOMAIN
        read -p "Existing project  : " ADD_PROJECT
        read -p "Existing user of project  : " ADD_USER
        read -s -p "Existing user MYSQL password  : " PASSWORD_MYSQL_USER
        echo '------------------------------------------------------------------------'
        echo 'Adding $ADD_DOMAIN to $ADD_PROJECT'
        echo '------------------------------------------------------------------------'

        # if the project exists...
        if [ -d "/home/${ADD_USER}/public/${ADD_PROJECT}" ]; then

            # Issue certificate for new domain name
            echo "${COLOUR_WHITE}>> Issuing new SSL for $ADD_DOMAIN ${COLOUR_RESTORE}"
            certbot -n --nginx certonly -d ${ADD_DOMAIN} -d www.${ADD_DOMAIN}

            # Add new domain name to virtual host
            echo "${COLOUR_WHITE}>> Adding ${ADD_DOMAIN} to virtual host conf ${COLOUR_RESTORE}"

            # Add new entry to the bottom of the file
            cat >> /etc/nginx/conf.d/${ADD_USER}-${ADD_PROJECT}.conf << EOF

# live domain https
server {
    server_name ${ADD_DOMAIN};
    include /etc/nginx/conf.d/${ADD_USER}-${ADD_PROJECT}.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${ADD_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${ADD_DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# redirect live domain https www to non www
server {
    server_name www.${ADD_DOMAIN};

    listen [::]:443 ssl;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/${ADD_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${ADD_DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    return 301 https://${ADD_DOMAIN}\$request_uri;

}

# redirect live domain http www to non www
server {
    server_name www.${ADD_DOMAIN};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}

# redirect live domain http to https
server {
    server_name ${ADD_DOMAIN};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}
EOF
            systemctl reload nginx

            # Changing paths in db
            echo "${COLOUR_WHITE}>> Changing paths in database...${COLOUR_RESTORE}"
            cat > /home/${ADD_USER}/public/${ADD_PROJECT}/db_changepaths.sql << EOF
UPDATE \`modx_context_setting\` SET \`value\`='${ADD_DOMAIN}' WHERE \`context_key\`='en' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${ADD_DOMAIN}' WHERE \`context_key\`='fr' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${ADD_DOMAIN}' WHERE \`context_key\`='es' AND \`key\`='http_host';
UPDATE \`modx_context_setting\` SET \`value\`='${ADD_DOMAIN}' WHERE \`context_key\`='pdf' AND \`key\`='http_host';

UPDATE \`modx_context_setting\` SET \`value\`='https://${ADD_DOMAIN}/' WHERE \`context_key\`='en' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${ADD_DOMAIN}/fr/' WHERE \`context_key\`='fr' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${ADD_DOMAIN}/es/' WHERE \`context_key\`='es' AND \`key\`='site_url';
UPDATE \`modx_context_setting\` SET \`value\`='https://${ADD_DOMAIN}/pdf/' WHERE \`context_key\`='pdf' AND \`key\`='site_url';
EOF

            echo "${COLOUR_CYAN}-- Importing db_changepaths.sql...${COLOUR_RESTORE}"
            mysql -u ${YAM_DATABASE_USER}_${ADD_USER}_${ADD_PROJECT} -p$PASSWORD_MYSQL_USER ${YAM_DATABASE_DB}_${ADD_USER}_${ADD_PROJECT} < /home/${ADD_USER}/public/${ADD_PROJECT}/db_changepaths.sql

            # Clean up database
            echo "${COLOUR_CYAN}-- Removing database installation files...${COLOUR_RESTORE}"
            rm /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql

            echo "Done."

        else
            echo "A development website does not exist with the credentials given."
            echo "Please check the information you provided and try again."
            exit
        fi



    else
        break
    fi
}

# Load addUserPasswordDirectory function
addUserPasswordDirectory() {
    if ask "Are you sure you want to add a new user to a password protected directory?"; then
        read -p "User home folder to edit  : " USER_FOLDER
        read -p "Username  : " USERNAME
        read -s -p "Password  : " PASSWORD
        echo
        echo '------------------------------------------------------------------------'
        echo 'Adding new user $USERNAME'
        echo '------------------------------------------------------------------------'

        htpasswd -b /home/${USER_FOLDER}/.htpasswd ${USERNAME} ${PASSWORD}

        echo "User added successfully."

    else
        break
    fi
}

# Load toggle password directory function
securePasswordDirectory() {
    if ask "Are you sure you want to toggle password directory?"; then
        read -p "Project name  : " PROJECT
        read -p "User  : " OWNER
        echo '------------------------------------------------------------------------'
        echo 'Checking password directory...'
        echo '------------------------------------------------------------------------'

        echo "${COLOUR_WHITE}>> password protecting directory...${COLOUR_RESTORE}"
        if [ -f "/etc/nginx/custom.d/${OWNER}-${PROJECT}.d/${PROJECT}.location.password.conf" ]; then
            echo "${COLOUR_CYAN}-- site is currently password protected. turning OFF protection...${COLOUR_RESTORE}"
            mv /etc/nginx/custom.d/${OWNER}-${PROJECT}.d/${PROJECT}.location.password.conf /etc/nginx/custom.d/${OWNER}-${PROJECT}.d/_${PROJECT}.location.password.conf
        else
            echo "${COLOUR_CYAN}-- site is currently not password protected. turning ON protection...${COLOUR_RESTORE}"
            mv /etc/nginx/custom.d/${OWNER}-${PROJECT}.d/_${PROJECT}.location.password.conf /etc/nginx/custom.d/${OWNER}-${PROJECT}.d/${PROJECT}.location.password.conf
        fi
        systemctl reload nginx

    else
        break
    fi
}

# Load delete user function
deleteUser() {
    if ask "Are you sure you want to delete a user? This will delete the users home folder and MYSQL access"; then
        read -p "User to delete  : " USER
        read -s -p "Confirm root MYSQL password  : " PASSWORD_MYSQL_ROOT
        echo
        echo '------------------------------------------------------------------------'
        echo 'Deleting user and all associated files'
        echo '------------------------------------------------------------------------'

        echo "${COLOUR_CYAN}-- deleting home folder ${COLOUR_RESTORE}"
        userdel -f ${USER}

        echo "${COLOUR_CYAN}-- removing access to MYSQL ${COLOUR_RESTORE}"
        mysql --user=root --password=${PASSWORD_MYSQL_ROOT} << EOF
DROP USER '${USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
        echo "${COLOUR_CYAN}-- removing log rotation${COLOUR_RESTORE}"
        rm /etc/logrotate.d/${USER}

        echo "${COLOUR_CYAN}-- removing related cron for backup${COLOUR_RESTORE}"
        rm /etc/cron.d/backup_local_${USER}
        rm /etc/cron.d/backup_s3_${USER}

        echo "Done."

    else
        break
    fi
}

# Load delete website function
deleteWebsite() {
    if ask "Are you sure you want to delete a website? This will delete the website from the users home folder, including the MYSQL database and NGINX conf files"; then
        read -p "Project name to delete  : " DEL_PROJECT_NAME
        read -p "Project URL  : " DEL_PROJECT_URL
        read -p "Which user owns the website?  : " USER
        echo '------------------------------------------------------------------------'
        echo 'Deleting website and all associated files'
        echo '------------------------------------------------------------------------'

        if id "$USER" >/dev/null 2>&1; then

            echo "${COLOUR_CYAN}-- deleting website in users home folder ${COLOUR_RESTORE}"
            rm -rf /home/${USER}/public/${DEL_PROJECT_NAME}

            echo "${COLOUR_CYAN}-- deleting sessions folder ${COLOUR_RESTORE}"
            rm -rf /home/${USER}/tmp/${DEL_PROJECT_NAME}

            echo "${COLOUR_CYAN}-- deleting log files ${COLOUR_RESTORE}"
            rm /home/${USER}/logs/nginx/${USER}_${DEL_PROJECT_NAME}_error.log

            echo "${COLOUR_CYAN}-- deleting website database from MYSQL ${COLOUR_RESTORE}"
            mysql --user=root << EOF
DROP USER '${YAM_DATABASE_USER}_${USER}_${DEL_PROJECT_NAME}'@'localhost';
DROP DATABASE ${YAM_DATABASE_DB}_${USER}_${DEL_PROJECT_NAME};
FLUSH PRIVILEGES;
EOF
            echo "${COLOUR_CYAN}-- cleaning up NGINX conf files ${COLOUR_RESTORE}"
            rm /etc/nginx/conf.d/${USER}-${DEL_PROJECT_NAME}.conf
            rm -rf /etc/nginx/conf.d/${USER}-${DEL_PROJECT_NAME}.d
            rm -rf /etc/nginx/custom.d/${USER}-${DEL_PROJECT_NAME}.d
            systemctl reload nginx

            echo "${COLOUR_CYAN}-- cleaning up PHP configuration ${COLOUR_RESTORE}"
            rm -rf /etc/php/7.1/fpm/pool.d/${USER}-${DEL_PROJECT_NAME}.conf
            systemctl reload php7.1-fpm

            echo "${COLOUR_CYAN}-- deleting SSL certificates ${COLOUR_RESTORE}"
            if [ -d "/etc/letsencrypt/renewal/${DEL_PROJECT_URL}.conf" ]; then
                rm -rf /etc/letsencrypt/renewal/${DEL_PROJECT_URL}.conf
            else
                echo "${COLOUR_CYAN}---- No renewal cert to delete. skipping...${COLOUR_RESTORE}"
            fi

            if [ -d "/etc/letsencrypt/live/${DEL_PROJECT_URL}" ]; then
                rm -rf /etc/letsencrypt/archive/${DEL_PROJECT_URL}
            else
                echo "${COLOUR_CYAN}---- No live cert to delete. skipping...${COLOUR_RESTORE}"
            fi

            if [ -d "/etc/letsencrypt/archive/${DEL_PROJECT_URL}" ]; then
                rm -rf /etc/letsencrypt/archive/${DEL_PROJECT_URL}
            else
                echo "${COLOUR_CYAN}---- No archive cert to delete. skipping...${COLOUR_RESTORE}"
            fi

            echo "Website removed."

        else
            echo "No website found. Skipping..."
        fi

    else
        break
    fi
}

# Display menu

echo ''
echo ' .----------------.  .----------------.  .----------------.'
echo '| .--------------. || .--------------. || .--------------. |'
echo '| |  ____  ____  | || |      __      | || | ____    ____ | |'
echo '| | |_  _||_  _| | || |     /  \     | || ||_   \  /   _|| |'
echo '| |   \ \  / /   | || |    / /\ \    | || |  |   \/   |  | |'
echo '| |    \ \/ /    | || |   / ____ \   | || |  | |\  /| |  | |'
echo '| |    _|  |_    | || | _/ /    \ \_ | || | _| |_\/_| |_ | |'
echo '| |   |______|   | || ||____|  |____|| || ||_____||_____|| |'
echo '| |              | || |              | || |              | |'
echo '| .--------------. || .--------------. || .--------------. |'
echo ' .----------------.  .----------------.  .----------------. '
echo ''
echo 'YAM_MANAGE.SH'


echo ''
echo 'What can I help you with today?'
echo ''
options=(
    "Add new development website"
    "Install a Basesite"
    "Add new development website with Basesite"
    "Package up website for injection"
    "Copy development website"
    "Map domain to development website"
    "Add user to password directory"
    "Toggle password directory"
    "Delete user"
    "Delete website"
    "Quit"
)

select option in "${options[@]}"; do
    case "$REPLY" in
        1) addVirtualhost ;;
        2) installBasesite ;;
        3) addVirtualhostBasesite ;;
        4) packageWebsite ;;
        5) copyVirtualhost ;;
        6) addDomain ;;
        7) addUserPasswordDirectory ;;
        8) securePasswordDirectory ;;
        9) deleteUser ;;
        10) deleteWebsite ;;
        11) break ;;
    esac
done
