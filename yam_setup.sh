#!/bin/bash

# YAM server configurator for Ubuntu 16.0.4
# by Jon Leverrier (jon@youandme.digital)
# Version 0.6

# USE AT YOUR OWN RISK!

# Installs and configures NGINX, MariaDB, PHP7.1 FPM, Cerbot (Let's Encrypt),
# PhpMyAdmin, Fail2Ban with UFW, php-imagick, htop, zip, unzip, Digital Ocean agent, s3cmd,
# nmap, yam_backup_local.sh, yam_backup_s3.sh, yam_sync_s3.sh and yam_backup_system.sh

# Also configures ssh keys, root and sudo users, time zone for server and mysql, skeleton directory,
# log rotation, ssl auto renewal, UFW, default error pages, local backup of core system folders,
# local backup of user web folders, S3 backup of core system folders, sessions, securing MODX, S3 backup
# of user web folders

# Whilst this script installs Amazon s3cmd, you'll have to run setup yourself. Was very
# quick todo, hence not adding it to the build script (s3cmd powers backups to AWS)

# Example usage:
# To install use wget -N https://example.com/yam_setup.sh
# Then run:
# /bin/bash yam_setup.sh as root user

# This script puts your websites in the following location:
# /home/user/public/website

# Change these settings below before running the script for the first time
YAM_EMAIL_BUG=$(echo -en 'bugs@youandme.digital')
YAM_EMAIL_SSL=$(echo -en 'jon@youandme.digital')
YAM_DATEFORMAT_TIMEZONE=$(echo -en 'Europe/Paris')

# if you have a MODX basesite that you work from enter the details below
YAM_BASESITE_PATH=$(echo -en '/home/yam/public/alphasite/')
YAM_BASESITE_DB=$(echo -en 'yam_db_yam_alphasite')

# initial generic password for protected directories. this will be overriden
# after setup
YAM_PASSWORD_GENERIC=$(echo -en '1q2w3e4r')

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

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
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

# Load setup server function
setupServer() {
    if ask "Are you sure you want to setup a new server?"; then
        read -p "Enter a sudo user  : " USER_SUDO
        read -p "Enter a sudo password  : " USER_SUDO_PASSWORD
        read -p "Enter a MYSQL password for sudo user  : " PASSWORD_MYSQL_SUDO
        read -p "Enter a MYSQL password for root user  : " PASSWORD_MYSQL_ROOT
        read -p "Enter a password for phpMyAdmin directory : " PASSWORD_PMA_DIR
        read -p "Enter domain name for the default website  : " URL_SERVER_DEFAULT
        read -p "Enter domain name for phpMyAdmin  : " URL_SERVER_PMA
        echo '------------------------------------------------------------------------'
        echo 'Setting up a new Ubuntu server'
        echo '------------------------------------------------------------------------'
        echo 'This will install NGINX, PHP7.1 FPM, MariaDB and core packages'
        echo ''
        if ask "Install with sudo?"; then
            echo "installing with sudo"
        else
            # INSTALLING AS ROOT
            echo "${COLOUR_WHITE}>> installing as root...${COLOUR_RESTORE}"

            # Adjusting server settings ...
            echo "${COLOUR_WHITE}>> adjusting server settings...${COLOUR_RESTORE}"

                # Adding log files
                touch /var/log/cron.log

                # Setting timezone
                echo "${COLOUR_CYAN}-- setting timezone to ${YAM_DATEFORMAT_TIMEZONE}${COLOUR_RESTORE}"
                ln -sf /usr/share/zoneinfo/${YAM_DATEFORMAT_TIMEZONE} /etc/localtime

                # Setting up skeleton directory
                echo "${COLOUR_CYAN}-- setting up skeleton directory${COLOUR_RESTORE}"
                mkdir -p /etc/skel/tmp
                mkdir -p /etc/skel/logs
                mkdir -p /etc/skel/logs/nginx
                mkdir -p /etc/skel/public

                # Adding a sudo user and setting password
                echo "${COLOUR_CYAN}-- adding sudo user and changing password${COLOUR_RESTORE}"
                useradd -m ${USER_SUDO}
                adduser ${USER_SUDO} sudo
                usermod --password ${USER_SUDO_PASSWORD} ${USER_SUDO}

                # Adding a sudo user and setting password
                echo "${COLOUR_CYAN}-- setting up log rotation for ${USER_SUDO} ${COLOUR_RESTORE}"
                cat > /etc/logrotate.d/${USER_SUDO} << EOF
/home/$USER/logs/nginx/*.log {
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
                echo "${COLOUR_CYAN}-- hardening host.conf ${COLOUR_RESTORE}"
                cat > /etc/host.conf << EOF
# The "order" line is only used by old versions of the C library.
order hosts,bind
multi on
nospoof on
EOF


            echo ">> Done."

            # Upgrade system and base packages
            echo "${COLOUR_WHITE}>> upgrading system and packages...${COLOUR_RESTORE}"
            apt-get update
            apt-get upgrade -y
            echo ">> Done."

            # Setup PPA
            echo "${COLOUR_WHITE}>> installing repositories...${COLOUR_RESTORE}"
            apt-get install -y --force-yes software-properties-common
            add-apt-repository -y ppa:ondrej/php
            add-apt-repository -y ppa:nijel/phpmyadmin
            add-apt-repository -y ppa:certbot/certbot
            apt-get -y --force-yes install apache2-utils
            apt-get update
            echo ">> Done."

            # Install SSL
            echo "${COLOUR_WHITE}>> installing SSL...${COLOUR_RESTORE}"
            apt-get install -y python-certbot-nginx
            echo ">> Done."

            # Configure SSL
            echo "${COLOUR_WHITE}>> configuring SSL...${COLOUR_RESTORE}"
            certbot -n --nginx certonly --agree-tos --email ${YAM_EMAIL_SSL} -d ${URL_SERVER_DEFAULT} -d ${URL_SERVER_PMA}
            echo ">> Done."

            # Install NGINX
            echo "${COLOUR_WHITE}>> installing NGINX...${COLOUR_RESTORE}"
            apt-get install -y --force-yes nginx
            echo ">> Done."

            # Configure NGINX
            echo "${COLOUR_WHITE}>> configuring NGINX...${COLOUR_RESTORE}"
            ufw allow 'Nginx Full'
            ufw delete allow 'Nginx HTTP'
            ufw delete allow 'Nginx HTTPS'

            # Disable The Default Nginx Site
            rm -rf /etc/nginx/sites-available/
            rm -rf /etc/nginx/sites-enabled/

            # Make changes to nginx.conf
            echo "${COLOUR_CYAN}-- making changes to nginx.conf${COLOUR_RESTORE}"

            # Backup the original nginx.conf file
            cp /etc/nginx/nginx.conf{,.bak}

            # Replace default nginx.conf file
            cat > /etc/nginx/nginx.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email $YAM_EMAIL_BUG

user www-data;
# work processes = the amount of cores the server has
worker_processes 1;
pid /run/nginx.pid;

events {
    use epoll;
    #in the terminal type "ulimit -n" to find out the number of worker connections
    worker_connections 1024;
}

http {

    ##
    # Basic Settings
    ##

    # copies data between one FD and other from within the kernel
    # faster then read() + write()
    sendfile on;

    # send headers in one peace, its better then sending them one by one
    tcp_nopush on;

    # don't buffer data sent, good for small data bursts in real time
    tcp_nodelay on;

    types_hash_max_size 2048;

    # hide what version of NGINX the server is running
    server_tokens off;

    server_names_hash_bucket_size 64;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # Buffers
    ##

    client_body_buffer_size 128K;
    client_header_buffer_size 1k;
    client_max_body_size 256m;
    large_client_header_buffers 4 8k;
    client_body_temp_path /tmp/client_body_temp;

    ##
    # Timeouts
    ##

    client_body_timeout 3000;
    client_header_timeout 3000;
    keepalive_timeout 3000;
    send_timeout 3000;

    ##
    # SSL Settings
    ##

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    # to boost I/O on HDD we can disable access logs
    access_log off;

    # default error log
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_min_length  256;
    gzip_disable "msie6";
    gzip_proxied expired no-cache no-store private auth;

    gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/default_server.conf;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/main_extra.conf;
}
EOF

            # Add main-extra.conf
            echo "${COLOUR_CYAN}-- adding main_extra.conf${COLOUR_RESTORE}"
            # Added if statement here to prevent the file being overwritten
            # if setup has already been run
            if [ -f /etc/nginx/main_extra.conf ]; then
                echo "${COLOUR_CYAN}-- main_extra.conf already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/nginx/main_extra.conf << EOF
# Generated by the YAM server configurator
EOF
            fi


            # Add default_server.conf
            echo "${COLOUR_CYAN}-- adding default_server.conf ${COLOUR_RESTORE}"
            cat > /etc/nginx/default_server.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# this file generates an error 404 if the server_name is not found under https
# it also defines the custom error pages used on the server

# /nginx/default_server.conf

server {
    listen	80 default_server;
    listen	[::]:80 default_server;

    # stop favicon generating 404
    location = /favicon.ico {
        log_not_found off;
    }

    include /etc/nginx/default_error_messages.conf;

    location / {
        return 404;
    }

}
EOF

            cat > /etc/nginx/default_error_messages.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/default_error_messages.conf

error_page 401 /401.html;
    location = /401.html {
        root /var/www/errors;
        internal;
}

error_page 403 /403.html;
    location = /403.html {
        root /var/www/errors;
        internal;
}

error_page 404 /404.html;
    location = /404.html {
        root /var/www/errors;
        internal;
}

error_page 500 /500.html;
    location = /500.html {
        root /var/www/errors;
        internal;
}

error_page 501 /501.html;
    location = /501.html {
        root /var/www/errors;
        internal;
}

error_page 502 /502.html;
    location = /502.html {
        root /var/www/errors;
        internal;
}

error_page 503 /503.html;
    location = /503.html {
        root /var/www/errors;
        internal;
}
EOF
            # Adding default conf file for default website
            echo "${COLOUR_CYAN}-- adding default conf file for default website${COLOUR_RESTORE}"
            cat > /etc/nginx/conf.d/_default.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/_default.conf

# dev url https
server {
    server_name ${URL_SERVER_DEFAULT};
    include /etc/nginx/conf.d/_default.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${URL_SERVER_DEFAULT}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${URL_SERVER_DEFAULT}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# dev url redirect http to https
server {
    server_name ${URL_SERVER_DEFAULT};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;

}

EOF

            # Adding default conf file for phpMyAdmin website
            echo "${COLOUR_CYAN}-- adding default conf file for phpMyAdmin website${COLOUR_RESTORE}"
            cat > /etc/nginx/conf.d/phpmyadmin.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/phpmyadmin.conf

# dev url https
server {
    server_name ${URL_SERVER_PMA};
    include /etc/nginx/conf.d/phpmyadmin.d/main.conf;
    include /etc/nginx/default_error_messages.conf;

    listen [::]:443 http2 ssl;
    listen 443 http2 ssl;
    ssl_certificate /etc/letsencrypt/live/${URL_SERVER_DEFAULT}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${URL_SERVER_DEFAULT}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}

# dev url redirect http to https
server {
    server_name ${URL_SERVER_PMA};
    return 301 https://\$host\$request_uri;

    listen 80;
    listen [::]:80;
}
EOF
            # Adding conf file and directory for default website
            echo "${COLOUR_CYAN}-- adding conf files and directory for default website${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/conf.d/_default.d
            cat > /etc/nginx/conf.d/_default.d/main.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/_default.d/main.conf

# custom headers file loads here if included
include /etc/nginx/custom.d/_default.d/_default.location.header.*.conf;

# setup php to use FPM
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm-default.sock;
}

# custom body file loads here if included
include /etc/nginx/custom.d/_default.d/_default.location.body.*.conf;

# stop favicon generating 404
location = /favicon.ico {
    log_not_found off;
}

# custom cache file loads here if included
include /etc/nginx/custom.d/_default.d/_default.location.footer.*.conf;

# as this is the default website, non existant sub domain names will
# redirect to this domain, so serve them an error 404
location / {
    return 404;
}
EOF

            # Adding conf file and directory for phpMyAdmin website
            echo "${COLOUR_CYAN}-- adding conf files and directory for phpmyadmin website${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/conf.d/phpmyadmin.d
            cat > /etc/nginx/conf.d/phpmyadmin.d/main.conf << EOF
# Generated by the YAM server configurator
# Do not edit as you may loose your changes
# If you have found a bug, please email ${YAM_EMAIL_BUG}

# /nginx/conf.d/phpmyadmin.d/main.conf

error_log           /home/${USER_SUDO}/logs/nginx/phpmyadmin_error.log;

# custom headers file loads here if included
include /etc/nginx/custom.d/phpmyadmin.d/phpmyadmin.location.header.*.conf;

# location of web root
root /home/${USER_SUDO}/public/phpmyadmin;
index index.php index.htm index.html;

# setup php to use FPM
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php7.1-fpm-phpmyadmin.sock;
}

# custom body file loads here if included
include /etc/nginx/custom.d/phpmyadmin.d/phpmyadmin.location.body.*.conf;

# prevent access to hidden files
location ~ /\. {
    deny all;
}

# stop favicon generating 404
location = /favicon.ico {
    log_not_found off;
}

# redirect to phpmyadmin folder
location = / {
    return 301 http://\$host/phpmyadmin;
}

# add password directory
location /phpmyadmin {
    auth_basic "Private";
    auth_basic_user_file /home/${USER_SUDO}/.htpasswd;
}

# custom cache file loads here if included
include /etc/nginx/custom.d/phpmyadmin.d/phpmyadmin.location.footer.*.conf;
EOF
            # Adding custom conf directory for default website
            echo "${COLOUR_CYAN}-- adding custom conf directory for default website${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/custom.d/_default.d
            cat > /etc/nginx/custom.d/_default.d/readme.txt << EOF
In this directory you can add custom rewrite rules in the follwing format.

_default.location.header.*.conf
_default.location.body.*.conf
_default.location.footer.*.conf

Don't forget to reload NGINX from the terminal using:
systemctl reload nginx
EOF
            # Adding custom conf directory for default website
            echo "${COLOUR_CYAN}-- adding custom conf directory for phpMyAdmin website${COLOUR_RESTORE}"
            mkdir -p /etc/nginx/custom.d/phpmyadmin.d
            cat > /etc/nginx/custom.d/phpmyadmin.d/readme.txt << EOF
In this directory you can add custom rewrite rules in the follwing format.

phpmyadmin.location.header.*.conf
phpmyadmin.location.body.*.conf
phpmyadmin.location.footer.*.conf

Don't forget to reload NGINX from the terminal using:
systemctl reload nginx
EOF
            # Adding default error pages
            echo "${COLOUR_CYAN}-- setting up custom error pages...${COLOUR_RESTORE}"
            mkdir -p /var/www/errors
            cat > /var/www/errors/401.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 401 - Unauthorized</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Unauthorized <small>Error 401</small></h1><p class="lead">The requested page requires authentication.</p></div>
</body>
</html>
EOF

            cat > /var/www/errors/403.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 403 - Access Denied</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Access Denied <small>Error 403</small></h1><p class="lead">The requested page requires an authentication.</p></div>

</body>
</html>
EOF

            cat > /var/www/errors/404.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 404 - Resource not found</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Page not found <small>Error 404</small></h1><p class="lead">The requested page could not be found but may be available again in the future.</p></div>
</body>
</html>
EOF

            cat > /var/www/errors/500.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 500 - Webservice currently unavailable</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Website currently unavailable <small>Error 500</small></h1><p class="lead">We are currently experiencing technical problems.<br />Please check back shortly.</p></div>
</body>
</html>
EOF

            cat > /var/www/errors/501.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 501 - Not Implemented</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Not Implemented <small>Error 501</small></h1><p class="lead">The Webserver cannot recognize the request method.</p></div>

</body>
</html>
EOF

            cat > /var/www/errors/502.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 502 - Webservice currently unavailable</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Website currently unavailable <small>Error 502</small></h1><p class="lead">We are currently experiencing technical problems.<br />Please check back shortly.</p></div>
</body>
</html>
EOF

            cat > /var/www/errors/503.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Simple HttpErrorPages | MIT License | https://github.com/AndiDittrich/HttpErrorPages -->
    <meta charset="utf-8" /><meta http-equiv="X-UA-Compatible" content="IE=edge" /><meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>We've got some trouble | 503 - Webservice currently unavailable</title>
    <style type="text/css">/*! normalize.css v5.0.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,footer,header,nav,section{display:block}h1{font-size:2em;margin:.67em 0}figcaption,figure,main{display:block}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}dfn{font-style:italic}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-.25em}sup{top:-.5em}audio,video{display:inline-block}audio:not([controls]){display:none;height:0}img{border-style:none}svg:not(:root){overflow:hidden}button,input,optgroup,select,textarea{font-family:sans-serif;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}[type=reset],[type=submit],button,html [type=button]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner,button::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring,button:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid silver;margin:0 2px;padding:.35em .625em .75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{display:inline-block;vertical-align:baseline}textarea{overflow:auto}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-cancel-button,[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details,menu{display:block}summary{display:list-item}canvas{display:inline-block}template{display:none}[hidden]{display:none}/*! Simple HttpErrorPages | MIT X11 License | https://github.com/AndiDittrich/HttpErrorPages */body,html{width:100%;height:100%;background-color:#21232a}body{color:#fff;text-align:center;text-shadow:0 2px 4px rgba(0,0,0,.5);padding:0;min-height:100%;-webkit-box-shadow:inset 0 0 100px rgba(0,0,0,.8);box-shadow:inset 0 0 100px rgba(0,0,0,.8);display:table;font-family:"Open Sans",Arial,sans-serif}h1{font-family:inherit;font-weight:500;line-height:1.1;color:inherit;font-size:36px}h1 small{font-size:68%;font-weight:400;line-height:1;color:#777}a{text-decoration:none;color:#fff;font-size:inherit;border-bottom:dotted 1px #707070}.lead{color:silver;font-size:21px;line-height:1.4}.cover{display:table-cell;vertical-align:middle;padding:0 20px}footer{position:fixed;width:100%;height:40px;left:0;bottom:0;color:#a0a0a0;font-size:14px}</style>
</head>
<body>
    <div class="cover"><h1>Website currently unavailable <small>Error 503</small></h1><p class="lead">We are currently experiencing technical problems.<br />Please check back shortly.</p></div>

</body>
</html>
EOF
            systemctl reload nginx
            echo ">> NGINX has been restarted. Configuration complete."

            # Install MYSQL
            echo "${COLOUR_WHITE}>> installing MariaDB...${COLOUR_RESTORE}"
            apt-get install -y --force-yes mariadb-server
            echo ">> Done."

            # Configure MYSQL
            echo "${COLOUR_WHITE}>> configuring MariaDB...${COLOUR_RESTORE}"

            # Do a manual mysql_secure_installation
            mysql --user=root --password=$PASSWORD_MYSQL_ROOT << EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${PASSWORD_MYSQL_ROOT}');
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';

CREATE USER '${USER_SUDO}'@'localhost' IDENTIFIED BY '${PASSWORD_MYSQL_SUDO}';
GRANT ALL PRIVILEGES ON *.* TO '${USER_SUDO}'@'localhost' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EOF
            # Set mysql time zone so it matches php
            mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql
            sed -i "/\[mysqld\]/a default_time_zone = Europe\/Paris" /etc/mysql/mariadb.conf.d/50-server.cnf

            echo ">> Done."

            # Install PHP7.1
            echo "${COLOUR_WHITE}>> installing PHP7.1...${COLOUR_RESTORE}"
            apt-get install -y php7.1 php7.1-fpm php7.1-cli php7.1-curl php7.1-common php7.1-mbstring php7.1-gd php7.1-intl php7.1-xml php7.1-mysql php7.1-mcrypt php7.1-zip

            # Configure PHP.7.1
            echo "${COLOUR_WHITE}>> configuring PHP7.1...${COLOUR_RESTORE}"

            # First backup original php.ini file
            cp /etc/php/7.1/fpm/php.ini /etc/php/7.1/fpm/php.ini.bak

            # Make changes to php.ini
            # These changes may be overwritten, so they're also included on a user level
            sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini
            sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/7.1/fpm/php.ini
            sed -i "s/;date.timezone.*/date.timezone = Europe\/Paris/" /etc/php/7.1/fpm/php.ini
            sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.1/fpm/php.ini
            sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.1/fpm/php.ini
            sed -i "s/default_socket_timeout = .*/default_socket_timeout = 120/" /etc/php/7.1/fpm/php.ini
            sed -i "s/;session.cookie_secure =/session.cookie_secure = 1/" /etc/php/7.1/fpm/php.ini
            sed -i "s/session.cookie_httponly =/session.cookie_httponly = 1/" /etc/php/7.1/fpm/php.ini
            sed -i 's#;session.save_path = "/var/lib/php/sessions"#session.save_path = "/var/lib/php/sessions"#' /etc/php/7.1/fpm/php.ini

            echo "${COLOUR_CYAN}-- adding php workers for default site and phpmyadmin${COLOUR_RESTORE}"
            # Delete default www.conf file
            rm -rf /etc/php/7.1/fpm/pool.d/www.conf

            # Add php pools for default website and phpmyadmin
            if [ -f /etc/php/7.1/fpm/pool.d/phpmyadmin.conf ]; then
                echo "${COLOUR_CYAN}-- pool configuration for phpmyadmin already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/php/7.1/fpm/pool.d/phpmyadmin.conf << EOF
[phpmyadmin]
user = ${USER_SUDO}
group = ${USER_SUDO}
listen = /var/run/php/php7.1-fpm-phpmyadmin.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_value[date.timezone] = ${YAM_DATEFORMAT_TIMEZONE}
php_value[cgi.fix_pathinfo] = 0
php_value[memory_limit] = 256M
php_value[upload_max_filesize] = 100M
php_value[default_socket_timeout] = 120
php_value[session.cookie_secure] = 1
php_value[session.cookie_httponly] = 1

EOF
            fi
            if [ -f /etc/php/7.1/fpm/pool.d/default.conf ]; then
                echo "${COLOUR_CYAN}-- pool configuration for default already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/php/7.1/fpm/pool.d/default.conf << EOF
[default]
user = ${USER_SUDO}
group = ${USER_SUDO}
listen = /var/run/php/php7.1-fpm-default.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 200
chdir = /
php_value[date.timezone] = ${YAM_DATEFORMAT_TIMEZONE}
php_value[cgi.fix_pathinfo] = 0
php_value[memory_limit] = 256M
php_value[upload_max_filesize] = 100M
php_value[default_socket_timeout] = 120
php_value[session.cookie_secure] = 1
php_value[session.cookie_httponly] = 1
EOF
            fi

            systemctl restart php7.1-fpm
            echo ">> Done."

            # Installing phpMyAdmin
            echo "${COLOUR_WHITE}>> installing phpMyAdmin...${COLOUR_RESTORE}"
            export DEBIAN_FRONTEND=noninteractive
            apt-get -y install phpmyadmin
            echo ">> Done."

            # Configuring phpMyAdmin
            echo "${COLOUR_WHITE}>> configuring phpMyAdmin...${COLOUR_RESTORE}"
            touch /home/${USER_SUDO}/logs/nginx/phpmyadmin_error.log
            mkdir -p /home/${USER_SUDO}/public/phpmyadmin

            # Stop phpmyadmin from being backedup
            touch /home/${USER_SUDO}/public/phpmyadmin/.nobackup

            # Set permissions on phpmyadmin folders to prevent errors
            chown -R ${USER_SUDO}:${USER_SUDO} /var/lib/phpmyadmin
            chown -R ${USER_SUDO}:${USER_SUDO} /etc/phpmyadmin
            chown -R ${USER_SUDO}:${USER_SUDO} /usr/share/phpmyadmin

            # Password protect phpmyadmin directory
            htpasswd -b -c /home/${USER_SUDO}/.htpasswd phpmyadmin ${PASSWORD_PMA_DIR}

            # Add user folder and create a system link to the public folder
            chown root:root /home/${USER_SUDO}
            chown -R ${USER_SUDO}:${USER_SUDO} /home/${USER_SUDO}/public
            chmod -R 755 /home/${USER_SUDO}
            chmod -R 755 /home/${USER_SUDO}/public
            sudo ln -s /usr/share/phpmyadmin /home/${USER_SUDO}/public/phpmyadmin
            echo ">> Done."

            # Install firewall
            echo "${COLOUR_WHITE}>> installing firewall...${COLOUR_RESTORE}"
            apt-get install -y fail2ban
            echo ">> Done."

            echo "${COLOUR_WHITE}>> configuring firewall...${COLOUR_RESTORE}"
            cat > /etc/fail2ban/action.d/ufw.conf << EOF
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = ufw insert 1 deny from <ip> to any
actionunban = ufw delete deny from <ip> to any
EOF
            cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
banaction = ufw
bantime = 86400
findtime = 3600
maxretry = 3

[ssh]
enabled = true
port = ssh
filter = sshd
action = ufw
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
action = ufw
EOF
            fail2ban-client reload

            ufw allow OpenSSH
            ufw --force enable
            echo ">> Done."

            echo "${COLOUR_CYAN}>> setting up SFTP${COLOUR_RESTORE}"

            # If setup is run again, check to make sure there config doesn't already exist
            if grep -Fxq "Match User ${USER_SUDO}" /etc/ssh/sshd_config
            then
                echo "${COLOUR_CYAN}-- SFTP user found. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
            cat >> /etc/ssh/sshd_config << EOF

Match User ${USER_SUDO}
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

            echo "${COLOUR_CYAN}>> setting up system backup${COLOUR_RESTORE}"
            cat > /etc/cron.d/backup_server_local << EOF
30 2    * * *   root    /root/yam_backup_system.sh >> /var/log/cron.log 2>&1

EOF
            cat > /etc/cron.d/backup_server_s3_nginx << EOF
30 3    * * *   root    /root/yam_sync_s3.sh /var/backups/nginx/ /servers/backups/${YAM_SERVER_NAME}/var/backups/nginx/ >> /var/log/cron.log 2>&1

EOF

            cat > /etc/cron.d/backup_server_s3_letsencrypt << EOF
30 3    * * *   root    /root/yam_sync_s3.sh /var/backups/letsencrypt/ /servers/backups/${YAM_SERVER_NAME}/var/backups/letsencrypt/ >> /var/log/cron.log 2>&1

EOF

            cat > /etc/cron.d/backup_server_s3_mysql << EOF
30 3    * * *   root    /root/yam_sync_s3.sh /var/backups/mysql/ /servers/backups/${YAM_SERVER_NAME}/var/backups/mysql/ >> /var/log/cron.log 2>&1

EOF

            cat > /etc/cron.d/backup_server_s3_ssh << EOF
30 3    * * *   root    /root/yam_sync_s3.sh /var/backups/ssh/ /servers/backups/${YAM_SERVER_NAME}/var/backups/ssh/ >> /var/log/cron.log 2>&1

EOF

            cat > /etc/cron.d/backup_server_s3_cron << EOF
30 3    * * *   root    /root/yam_sync_s3.sh /var/backups/cron/ /servers/backups/${YAM_SERVER_NAME}/var/backups/cron/ >> /var/log/cron.log 2>&1

EOF

            # Install additional packages
            echo "${COLOUR_WHITE}>> installing additional packages...${COLOUR_RESTORE}"
            apt-get install -y php-imagick
            apt-get install -y htop zip unzip s3cmd nmap
            apt-get clean
            systemctl reload nginx
            apt-get purge -y snapd
            curl -sSL https://agent.digitalocean.com/install.sh | sh

            # Install yam utilities
            echo "${COLOUR_WHITE}>> installing yam server utilities...${COLOUR_RESTORE}"
            wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_local.sh
            wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_s3.sh
            wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_sync_s3.sh
            wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_backup_system.sh
            chmod -R 700 /root/yam_backup_local.sh
            chmod -R 700 /root/yam_backup_s3.sh
            chmod -R 700 /root/yam_sync_s3.sh
            chmod -R 700 /root/yam_backup_system.sh
            echo ">> Done."

        fi
    else
        break
    fi
}

# Load secure server function
secureServer() {
    if ask "Are you sure you want to setup a sudo user?"; then
        read -p "Enter a sudo user  : " USER_SUDO
        read -p "Enter a sudo password  : " USER_SUDO_PASSWORD
        read -p "Paste SSH Keys  : " KEY_SSH_PUBLIC
        echo '------------------------------------------------------------------------'
        echo 'Securing server'
        echo '------------------------------------------------------------------------'

        # Check to see if whois is installed on the server
        echo "${COLOUR_WHITE}>> checking to see if package whois is installed...${COLOUR_RESTORE}"
        if [ $(dpkg-query -W -f='${Status}' whois 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
            apt-get install whois;
        else
            echo "Done. The whois package is already installed."
        fi

        # Setting up new sudo user
        echo "${COLOUR_WHITE}>> setting up new sudo user and password for ${USER_SUDO}...${COLOUR_RESTORE}"

        if id "$USER_SUDO" >/dev/null 2>&1; then
              echo "The user already exists. Skipping..."
        else
            useradd -m ${USER_SUDO}
            adduser ${USER_SUDO} sudo

            PASSWORD=$(mkpasswd ${USER_SUDO_PASSWORD})
            usermod --password ${PASSWORD} ${USER_SUDO}
            echo "Done."
        fi

        # Setup Bash For User
        echo "${COLOUR_WHITE}>> setting up bash for ${USER_SUDO}...${COLOUR_RESTORE}"
        chsh -s /bin/bash ${USER_SUDO}
        echo "Done."

        # Add keys to root and user folders
        echo "${COLOUR_WHITE}>> setting up keys for root and ${USER_SUDO}...${COLOUR_RESTORE}"
        cat > /root/.ssh/authorized_keys << EOF
$KEY_SSH_PUBLIC
EOF
        if [ -f "/home/$USER_SUDO/.ssh" ]; then
            echo "A .ssh folder already exists in the home folder for ${USER_SUDO}. Skipping..."
        else
            mkdir -p /home/${USER_SUDO}/.ssh
            cp /root/.ssh/authorized_keys /home/${USER_SUDO}/.ssh/authorized_keys
            echo "Done."

            # Create The Server SSH Key
            ssh-keygen -f /home/${USER_SUDO}/.ssh/id_rsa -t rsa -N ''
            chmod 700 /home/${USER_SUDO}/.ssh/id_rsa
            chmod 600 /home/${USER_SUDO}/.ssh/authorized_keys
        fi

        # Setup Site Directory Permissions
        echo "${COLOUR_WHITE}>> adjusting user permissions...${COLOUR_RESTORE}"
        if [ -d "/home/$USER_SUDO" ]; then
            echo "A home folder already exists. Skipping..."
        else
            chown -R ${USER_SUDO}:${USER_SUDO} /home/${USER_SUDO}
            chmod -R 755 /home/${USER_SUDO}
            chown root:root /home/${USER_SUDO}
            echo "Done."
        fi



    else
        break
    fi
}

# Load install basesite function
installBasesite() {
    if ask "Are you sure you want to inject a MODX website from an external source?"; then
        read -p "Which project do you want to install MODX? : " PROJECT_NAME
        read -p "Who owns the project? : " PROJECT_OWNER
        read -p "Project mysql password : " PASSWORD_MYSQL
        read -p "Project test url : " PROJECT_DOMAIN
        read -p "Name of MODX folder (without zip) : " FOLDER_MODX_ZIP
        read -p "URL to MODX zip : " URL_MODX
        read -p "URL to database dump : " URL_DATABASE
        read -p "URL to assets zip : " URL_ASSETS
        read -p "URL to core/packages zip : " URL_PACKAGES
        read -p "URL to core/components zip : " URL_COMPONENTS
        echo '------------------------------------------------------------------------'
        echo 'Installing MODX'
        echo '------------------------------------------------------------------------'

        if [ -d "/home/$PROJECT_OWNER/$PROJECT_NAME" ]; then
            echo "-- Changing path to /home/${PROJECT_OWNER}/public/${PROJECT_NAME}"
            # Navigate to the desired project folder
            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}
        else
            echo "-- Creating directory and changing path to /home/${PROJECT_OWNER}/public/${PROJECT_NAME}"
            mkdir -p /home/${PROJECT_OWNER}/public/${PROJECT_NAME}
            cd /home/${PROJECT_OWNER}/public/${PROJECT_NAME}
        fi

        # Stop backups by default
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

        echo "${COLOUR_CYAN}-- deleting existing config files in root, core, manager and connectors... ${COLOUR_RESTORE}"
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/config/config.inc.php
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/config.core.php
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/config.core.php
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/config.core.php

        echo "${COLOUR_WHITE}>> installing new MODX config files...${COLOUR_RESTORE}"
        if [ -f /home/$PROJECT_OWNER/public/$PROJECT_NAME/core/config/config.inc.php ]; then
            echo "-- MODX core config file already exists. Skipping..."
        else
            cat > /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = 'yam_dbuser_${PROJECT_OWNER}_${PROJECT_NAME}';
\$database_password = '${PASSWORD_MYSQL}';
\$database_connection_charset = 'utf8';
\$dbase = 'yam_db_${PROJECT_OWNER}_${PROJECT_NAME}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=yam_db_${PROJECT_OWNER}_${PROJECT_NAME};charset=utf8';
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
        fi

        # Add manager config for MODX
        if [ -f /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/manager/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX manager config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add connectors config for MODX
        if [ -f /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/connectors/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX connectors config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add root config for MODX
        if [ -f /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX root config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

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
        mysql -uyam_dbuser_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} yam_db_${PROJECT_OWNER}_${PROJECT_NAME} < /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/${URL_DATABASE##*/}

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
        mysql -uyam_dbuser_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} yam_db_${PROJECT_OWNER}_$PROJECT_NAME < /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/db_changepaths.sql

        # Delete any session data from previous database
        mysql -uyam_dbuser_${PROJECT_OWNER}_${PROJECT_NAME} -p${PASSWORD_MYSQL} yam_db_${PROJECT_OWNER}_${PROJECT_NAME} << EOF
truncate modx_session;
EOF

        # Clean up database
        echo "${COLOUR_CYAN}-- removing installation files...${COLOUR_RESTORE}"
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/${URL_DATABASE##*/}
        rm /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/db_changepaths.sql

        # Set permissions, just incase...
        echo "${COLOUR_CYAN}-- adjusting permissions...${COLOUR_RESTORE}"
        rm -rf /home/${PROJECT_OWNER}/public/${PROJECT_NAME}/core/cache
        chown -R ${PROJECT_OWNER}:${PROJECT_OWNER} /home/${PROJECT_OWNER}/public/${PROJECT_NAME}

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
        mysqldump -u root yam_db_${PROJECT_OWNER}_${PROJECT_NAME} > /home/${PROJECT_OWNER}/backup/temp/yam_db_${PROJECT_OWNER}_${PROJECT_NAME}.sql

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
        break
    fi
}

# Load add virtual host function
addVirtualhost() {
    if ask "Are you sure you want to add a new development website?"; then
        read -p "Name of project (all one word, no spaces)  : " PROJECT_NAME
        read -p "Enter owner (user) of project  : " USER
        read -p "Enter user password  : " USER_PASSWORD
        read -p "Enter test domain name  : " PROJECT_DOMAIN
        read -p "Enter MYSQL password  : " DB_PASSWORD
        read -p "Enter MYSQL root password  : " DB_PASSWORD_ROOT
        echo '------------------------------------------------------------------------'
        echo 'Setting up virtual host'
        echo '------------------------------------------------------------------------'

        # Add user to server
        echo "${COLOUR_WHITE}>> checking user account for ${USER}...${COLOUR_RESTORE}"
        if id "$USER" >/dev/null 2>&1; then
              echo "The user already exists. Skipping..."
        else
            echo "${COLOUR_CYAN}-- adding user${COLOUR_RESTORE}"
            useradd -m ${USER}
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


            echo "${COLOUR_CYAN}-- adding cron job for backups${COLOUR_RESTORE}"

            if [ -f /etc/cron.d/backup_local_${USER} ]; then
                echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_local_${USER} << EOF
30 2    * * *   root    /root/yam_backup_local.sh ${USER} >> /var/log/cron.log 2>&1

EOF
            fi

            if [ -f /etc/cron.d/backup_s3_${USER} ]; then
                echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_s3_${USER} << EOF
* 3    * * *   root    /root/yam_backup_s3.sh $USER ${YAM_SERVER_NAME} >> /var/log/cron.log 2>&1

EOF
            fi

            echo "${COLOUR_CYAN}-- setting up SFTP${COLOUR_RESTORE}"
            if grep -Fxq "Match User $USER" /etc/ssh/sshd_config
            then
                echo "${COLOUR_CYAN}-- SFTP user found. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
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
        echo "${COLOUR_WHITE}>> creating home folder for ${USER}...${COLOUR_RESTORE}"
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
            echo "${COLOUR_CYAN}-- log files for ${PROJECT_NAME} already exist. Skipping...${COLOUR_RESTORE}"
        else
            echo "${COLOUR_CYAN}-- creating log files${COLOUR_RESTORE}"
            touch /home/${USER}/logs/nginx/${USER}_${PROJECT_NAME}_error.log
        fi

        # Configure SSL
        echo "${COLOUR_WHITE}>> configuring SSL...${COLOUR_RESTORE}"
        certbot -n --nginx certonly -d ${PROJECT_DOMAIN}
        echo "Done."

        echo "${COLOUR_WHITE}>> configuring NGINX${COLOUR_RESTORE}"
        # Adding virtual host for user
        echo "${COLOUR_CYAN}-- adding default conf file for $PROJECT_NAME...${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding conf files and directory for ${PROJECT_NAME} ${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding custom conf directory for $PROJECT_NAME ${COLOUR_RESTORE}"
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

        echo "${COLOUR_WHITE}>> configuring php...${COLOUR_RESTORE}"
        if [ -f /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf ]; then
            echo "pool configuration for ${USER}-${PROJECT_NAME} already exists. Skipping..."
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
            echo "-- Added php worker for ${USER}-${PROJECT_NAME}."
        fi

        # Create database and user
        echo "${COLOUR_WHITE}>> setting up database...${COLOUR_RESTORE}"
        mysql --user=root --password=$DB_PASSWORD_ROOT << EOF
CREATE DATABASE IF NOT EXISTS yam_db_${USER}_${PROJECT_NAME};
CREATE USER 'yam_dbuser_${USER}_${PROJECT_NAME}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON yam_db_${USER}_${PROJECT_NAME}.* TO 'yam_dbuser_${USER}_${PROJECT_NAME}'@'localhost';
FLUSH PRIVILEGES;
EOF
        echo ">> Done."



    else
        break
    fi
}

# Load add virtual host with basesite function
addVirtualhostBasesite() {
    if ask "Are you sure you want to setup a new Virtual Host with Basesite installed?"; then
        read -p "Name of project (all one word, no spaces)  : " PROJECT_NAME
        read -p "Enter owner (user) of project  : " USER
        read -p "Enter user password  : " PASSWORD_USER
        read -p "Enter test domain name  : " DOMAIN_TEST
        read -p "Enter MYSQL password  : " PASSWORD_MYSQL_USER
        read -p "Enter MYSQL root password  : " PASSWORD_MYSQL_ROOT
        echo '------------------------------------------------------------------------'
        echo 'Setting up virtual host with Basesite'
        echo '------------------------------------------------------------------------'

        # Add user to server
        echo "${COLOUR_WHITE}>> checking user account for ${USER}...${COLOUR_RESTORE}"
        if id "$USER" >/dev/null 2>&1; then
              echo "-- The user already exists. Skipping..."
        else
            useradd -m ${USER}
            PASSWORD=$(mkpasswd ${PASSWORD_USER})
            usermod --password ${PASSWORD} ${USER}

            chown root:root /home/${USER}

            echo "${COLOUR_CYAN}-- Added user ${COLOUR_RESTORE}"

            echo "${COLOUR_CYAN}-- Setting up log rotation ${COLOUR_RESTORE}"
            if [ -f /etc/logrotate.d/$USER ]; then
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


            echo "${COLOUR_CYAN}-- adding cron job for backups${COLOUR_RESTORE}"

            if [ -f /etc/cron.d/backup_local_$USER ]; then
                echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_local_$USER << EOF
30 2    * * *   root    /root/yam_backup_local.sh $USER >> /var/log/cron.log 2>&1

EOF
            fi

            if [ -f /etc/cron.d/backup_s3_$USER ]; then
                echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_s3_$USER << EOF
* 3    * * *   root    /root/yam_backup_s3.sh $USER $YAM_SERVER_NAME >> /var/log/cron.log 2>&1

EOF
            fi


            echo "${COLOUR_CYAN}-- setting up SFTP${COLOUR_RESTORE}"
            if grep -Fxq "Match User $USER" /etc/ssh/sshd_config
            then
                echo "${COLOUR_CYAN}-- SFTP user found. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
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
        echo "${COLOUR_WHITE}>> creating project folder for ${USER}...${COLOUR_RESTORE}"
        mkdir -p /home/${USER}/public/${PROJECT_NAME}
        touch /home/${USER}/public/${PROJECT_NAME}/.nobackup

        # Create sessions folder
        mkdir -p /home/${USER}/tmp/${PROJECT_NAME}
        chown -R ${USER}:${USER} /home/${USER}/tmp

        # Installing Basesite
        echo "${COLOUR_WHITE}>> installing Basesite ${USER}...${COLOUR_RESTORE}"

        echo "${COLOUR_CYAN}-- copying Basesite from base to ${PROJECT_NAME} ${COLOUR_RESTORE}"
        cp -R ${YAM_BASESITE_PATH}. /home/${USER}/public/${PROJECT_NAME}

        echo "${COLOUR_CYAN}-- deleting existing config files in core, manager and connectors... ${COLOUR_RESTORE}"
        rm /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php
        rm /home/${USER}/public/${PROJECT_NAME}/connectors/config.core.php
        rm /home/${USER}/public/${PROJECT_NAME}/manager/config.core.php
        rm /home/${USER}/public/${PROJECT_NAME}/config.core.php

        echo "${COLOUR_CYAN}-- deleting cache folder${COLOUR_RESTORE}"
        rm -rf /home/${USER}/public/${PROJECT_NAME}/core/cache/

        echo "${COLOUR_WHITE}>> installing MODX config files...${COLOUR_RESTORE}"

        # Add core config for MODX
        if [ -f /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php ]; then
            echo "${COLOUR_CYAN}-- MODX core config file already exists. Skipping...${COLOUR_RESTORE}"
        else
            cat > /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = 'yam_dbuser_${USER}_${PROJECT_NAME}';
\$database_password = '${PASSWORD_MYSQL_USER}';
\$database_connection_charset = 'utf8';
\$dbase = 'yam_db_${USER}_${PROJECT_NAME}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=yam_db_${USER}_${PROJECT_NAME};charset=utf8';
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
        fi

        # Add manager config for MODX
        if [ -f /home/$USER/public/$PROJECT_NAME/manager/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX manager config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add connectors config for MODX
        if [ -f /home/$USER/public/$PROJECT_NAME/connectors/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX connectors config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add root config for MODX
        if [ -f /home/$USER/public/$PROJECT_NAME/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX root config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Secure / change permissions on config file after save
        echo "${COLOUR_CYAN}-- adjusting permissions...${COLOUR_RESTORE}"
        chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/core/config/config.inc.php
        chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/manager/config.core.php
        chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/connectors/config.core.php
        chmod -R 644 /home/${USER}/public/${PROJECT_NAME}/config.core.php

        # Change permissions
        chown -R ${USER}:${USER} /home/${USER}/public/${PROJECT_NAME}

        # Password protect directory by default
        echo "${COLOUR_CYAN}-- password protecting directory...${COLOUR_RESTORE}"
        if [ -f "/home/$USER/.htpasswd" ]; then
            echo "${COLOUR_CYAN}-- .htpassword file exists. adding user.${COLOUR_RESTORE}"
            htpasswd -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
        else
            echo "${COLOUR_CYAN}-- .htpassword file does not exist. creating file and adding user.${COLOUR_RESTORE}"
            htpasswd -c -b /home/${USER}/.htpasswd ${PROJECT_NAME} ${YAM_PASSWORD_GENERIC}
        fi

        # Create log files
        echo "${COLOUR_WHITE}>> creating log files...${COLOUR_RESTORE}"
        if [ -e "/home/$USER/logs/nginx/${USER}_${PROJECT_NAME}_error.log" ]; then
            echo "${COLOUR_CYAN}-- log files for ${PROJECT_NAME} already exist. Skipping...${COLOUR_RESTORE}"
        else
            touch /home/${USER}/logs/nginx/${USER}_${PROJECT_NAME}_error.log
        fi

        # Configure SSL
        echo "${COLOUR_WHITE}>> configuring SSL...${COLOUR_RESTORE}"
        certbot -n --nginx certonly -d ${DOMAIN_TEST}

        echo "${COLOUR_WHITE}>> configuring NGINX${COLOUR_RESTORE}"
        # Adding virtual host for user
        echo "${COLOUR_CYAN}-- adding default conf file for ${PROJECT_NAME}...${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding conf files and directory for $PROJECT_NAME ${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding custom conf directory for ${PROJECT_NAME} ${COLOUR_RESTORE}"
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
        echo "NGINX configuration complete."

        echo "${COLOUR_WHITE}>> configuring php...${COLOUR_RESTORE}"
        if [ -f /etc/php/7.1/fpm/pool.d/${USER}-${PROJECT_NAME}.conf ]; then
            echo "-- pool configuration for ${PROJECT_NAME} already exists. Skipping..."
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
        echo "${COLOUR_WHITE}>> setting up database...${COLOUR_RESTORE}"
        mysql --user=root --password=${PASSWORD_MYSQL_ROOT} << EOF
CREATE DATABASE IF NOT EXISTS yam_db_${USER}_${PROJECT_NAME};
CREATE USER 'yam_dbuser_${USER}_${PROJECT_NAME}'@'localhost' IDENTIFIED BY '${PASSWORD_MYSQL_USER}';
GRANT ALL PRIVILEGES ON yam_db_${USER}_${PROJECT_NAME}.* TO 'yam_dbuser_${USER}_${PROJECT_NAME}'@'localhost';
FLUSH PRIVILEGES;
EOF
        # Copy Basesite db and import into new project
        echo "${COLOUR_CYAN}-- injecting Basesite into database...${COLOUR_RESTORE}"
        # Export
        mysqldump -u root ${YAM_BASESITE_DB} > /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql
        # Import
        mysql -u yam_dbuser_${USER}_${PROJECT_NAME} -p${PASSWORD_MYSQL_USER} yam_db_${USER}_${PROJECT_NAME} < /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql

        # Changing paths in db
        echo "${COLOUR_CYAN}-- exporting db_changepaths.sql...${COLOUR_RESTORE}"
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

        echo "${COLOUR_CYAN}-- importing db_changepaths.sql...${COLOUR_RESTORE}"
        mysql -u yam_dbuser_${USER}_${PROJECT_NAME} -p$PASSWORD_MYSQL_USER yam_db_${USER}_${PROJECT_NAME} < /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql

        # Delete any session data from previous database
        mysql -u yam_dbuser_${USER}_${PROJECT_NAME} -p${PASSWORD_MYSQL_USER} yam_db_${USER}_${PROJECT_NAME} << EOF
truncate modx_session;
EOF

        # Clean up database
        echo "${COLOUR_CYAN}-- removing database installation files...${COLOUR_RESTORE}"
        rm /home/${USER}/public/${PROJECT_NAME}/db_changepaths.sql
        rm /home/${USER}/public/${PROJECT_NAME}/db_basesite.sql

        echo "Installation complete."



    else
        break
    fi
}

# Map domain to website function
copyVirtualhost() {
    if ask "Are you sure you want to copy a development website?"; then
        read -p "Copy: Project  : " COPY_PROJECT
        read -p "Copy: Owner  : " COPY_USER
        read -p "New: Project  : " NEW_PROJECT
        read -p "New: Owner  : " NEW_USER
        read -p "New: Owner Password  : " NEW_PASSWORD_OWNER
        read -p "New: MYSQL Password  : " NEW_PASSWORD_MYSQL
        read -p "New: URL  : " NEW_URL
        echo '------------------------------------------------------------------------'
        echo 'Copying project...'
        echo '------------------------------------------------------------------------'

        # Add user to server if it doesn't exist
        echo "${COLOUR_WHITE}>> checking user account for ${NEW_USER}...${COLOUR_RESTORE}"
        if id "${NEW_USER}" >/dev/null 2>&1; then
              echo "-- The user already exists. Skipping..."
        else
            useradd -m ${NEW_USER}
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


            echo "${COLOUR_CYAN}-- adding cron job for backups${COLOUR_RESTORE}"
            if [ -f /etc/cron.d/backup_local_${NEW_USER} ]; then
                echo "${COLOUR_CYAN}-- Cron for local backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_local_${NEW_USER} << EOF
30 2    * * *   root    /root/yam_backup_local.sh ${NEW_OWNER} >> /var/log/cron.log 2>&1

EOF
            fi
            if [ -f /etc/cron.d/backup_s3_${NEW_USER} ]; then
                echo "${COLOUR_CYAN}-- Cron for s3 backup already exists. Skipping...${COLOUR_RESTORE}"
            else
                cat > /etc/cron.d/backup_s3_${NEW_USER} << EOF
* 3    * * *   root    /root/yam_backup_s3.sh ${NEW_OWNER} ${YAM_SERVER_NAME} >> /var/log/cron.log 2>&1

EOF
            fi

            echo "${COLOUR_CYAN}-- setting up SFTP${COLOUR_RESTORE}"
            if grep -Fxq "Match User ${NEW_OWNER}" /etc/ssh/sshd_config
            then
                echo "${COLOUR_CYAN}-- SFTP user found. Skipping...${COLOUR_RESTORE}"
            else
                echo "${COLOUR_CYAN}-- No SFTP user found. Adding new user...${COLOUR_RESTORE}"
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
        echo "${COLOUR_WHITE}>> creating project folder for ${NEW_USER}...${COLOUR_RESTORE}"
        mkdir -p /home/${NEW_USER}/public/${NEW_PROJECT}

        # Create new session folder
        mkdir -p /home/${NEW_USER}/tmp/${NEW_PROJECT}
        chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/tmp/${NEW_PROJECT}

        # Copy project a to b
        echo "${COLOUR_WHITE}>> copying ${COPY_PROJECT} owned by ${COPY_USER} to ${NEW_PROJECT} owned by ${NEW_USER}...${COLOUR_RESTORE}"
        cp -R /home/${COPY_USER}/public/${COPY_PROJECT}/. /home/${NEW_USER}/public/${NEW_PROJECT}
        touch /home/${NEW_USER}/public/${NEW_PROJECT}/.nobackup

        # Password protect directory by default
        echo "${COLOUR_WHITE}>> password protecting directory...${COLOUR_RESTORE}"
        if [ -f "/home/${NEW_USER}/.htpasswd" ]; then
            echo "${COLOUR_CYAN}-- .htpassword file exists. adding user.${COLOUR_RESTORE}"
            htpasswd -b /home/${NEW_USER}/.htpasswd ${NEW_PROJECT} ${YAM_PASSWORD_GENERIC}
        else
            echo "${COLOUR_CYAN}-- .htpassword file does not exist. creating file and adding user.${COLOUR_RESTORE}"
            htpasswd -c -b /home/${NEW_USER}/.htpasswd ${NEW_PROJECT} ${YAM_PASSWORD_GENERIC}
        fi

        # Configure SSL
        echo "${COLOUR_WHITE}>> configuring SSL...${COLOUR_RESTORE}"
        certbot -n --nginx certonly -d ${NEW_URL}

        echo "${COLOUR_WHITE}>> configuring NGINX${COLOUR_RESTORE}"
        # Adding virtual host for user
        echo "${COLOUR_CYAN}-- adding default conf file for ${NEW_PROJECT}...${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding conf files and directory for ${NEW_PROJECT} ${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- adding custom conf directory for ${NEW_PROJECT} ${COLOUR_RESTORE}"
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

        echo "${COLOUR_WHITE}>> configuring php...${COLOUR_RESTORE}"
        if [ -f /etc/php/7.1/fpm/pool.d/${NEW_USER}-${NEW_PROJECT}.conf ]; then
            echo "-- pool configuration for ${NEW_PROJECT} already exists. Skipping..."
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
        echo "${COLOUR_WHITE}>> setting up new mysql user and database...${COLOUR_RESTORE}"
        mysql --user=root << EOF
CREATE DATABASE IF NOT EXISTS yam_db_${NEW_USER}_${NEW_PROJECT};
CREATE USER 'yam_dbuser_${NEW_USER}_${NEW_PROJECT}'@'localhost' IDENTIFIED BY '${NEW_PASSWORD_MYSQL}';
GRANT ALL PRIVILEGES ON yam_db_${NEW_USER}_${NEW_PROJECT}.* TO 'yam_dbuser_${NEW_USER}_${NEW_PROJECT}'@'localhost';
FLUSH PRIVILEGES;
EOF

        # Copy basesite db and import into new project
        echo "${COLOUR_WHITE}>> installing database...${COLOUR_RESTORE}"
        # Export
        mysqldump -u root yam_db_${COPY_USER}_${COPY_PROJECT} > /home/${NEW_USER}/public/${NEW_PROJECT}/yam_db_${COPY_USER}_${COPY_PROJECT}.sql
        # Import
        mysql -u yam_dbuser_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} yam_db_${NEW_USER}_${NEW_PROJECT} < /home/${NEW_USER}/public/${NEW_PROJECT}/yam_db_${COPY_USER}_${COPY_PROJECT}.sql

        # Changing paths in db
        echo "${COLOUR_CYAN}-- exporting db_changepaths.sql...${COLOUR_RESTORE}"
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
        echo "${COLOUR_CYAN}-- deleting any session data from previous database...${COLOUR_RESTORE}"
        mysql -u yam_dbuser_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} yam_db_${NEW_USER}_${NEW_PROJECT} << EOF
truncate modx_session;
EOF

        echo "${COLOUR_CYAN}-- importing db_changepaths.sql...${COLOUR_RESTORE}"
        mysql -u yam_dbuser_${NEW_USER}_${NEW_PROJECT} -p${NEW_PASSWORD_MYSQL} yam_db_${NEW_USER}_${NEW_PROJECT} < /home/${NEW_USER}/public/${NEW_PROJECT}/db_changepaths.sql

        # Clean up database
        echo "${COLOUR_CYAN}-- removing database installation files...${COLOUR_RESTORE}"
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/yam_db_${COPY_USER}_${COPY_PROJECT}.sql
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/db_changepaths.sql

        # Delete config files and delete cache folder
        echo "${COLOUR_WHITE}>> deleting existing config files in core, manager and connectors... ${COLOUR_RESTORE}"
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php
        rm /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php

        echo "${COLOUR_WHITE}>> deleting cache folder${COLOUR_RESTORE}"
        rm -rf /home/${NEW_USER}/public/${NEW_PROJECT}/core/cache/

        # Add core config for MODX
        echo "${COLOUR_WHITE}>> installing new config files...${COLOUR_RESTORE}"
        if [ -f /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php ]; then
            echo "${COLOUR_CYAN}-- MODX core config file already exists. Skipping...${COLOUR_RESTORE}"
        else
            cat > /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php << EOF
<?php
/**
 *  MODX Configuration file
 */
\$database_type = 'mysql';
\$database_server = '127.0.0.1';
\$database_user = 'yam_dbuser_${NEW_USER}_${NEW_PROJECT}';
\$database_password = '${NEW_PASSWORD_MYSQL}';
\$database_connection_charset = 'utf8';
\$dbase = 'yam_db_${NEW_USER}_${NEW_PROJECT}';
\$table_prefix = 'modx_';
\$database_dsn = 'mysql:host=127.0.0.1;dbname=yam_db_${NEW_USER}_${NEW_PROJECT};charset=utf8';
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
        fi

        # Add manager config for MODX
        if [ -f /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX manager config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add connectors config for MODX
        if [ -f /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX connectors config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Add root config for MODX
        if [ -f /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php ]; then
            echo "${COLOUR_CYAN}-- MODX root config file already exists. Skipping...${COLOUR_RESTORE}"
        else
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
        fi

        # Secure / change permissions on config file after save
        echo "${COLOUR_WHITE}>> adjusting permissions...${COLOUR_RESTORE}"
        chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/core/config/config.inc.php
        chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/manager/config.core.php
        chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/connectors/config.core.php
        chmod -R 644 /home/${NEW_USER}/public/${NEW_PROJECT}/config.core.php

        # Change permissions
        chown -R ${NEW_USER}:${NEW_USER} /home/${NEW_USER}/public/${NEW_PROJECT}

        echo "${COLOUR_WHITE}Copy complete.${COLOUR_RESTORE}"

    else
        break
    fi
}

# Map domain to website function
addDomain() {
    if ask "Are you sure you want to add a domain to a website?"; then
        read -p "What domain name do you want to add  : " ADD_DOMAIN
        read -p "Which website should this be mapped to?  : " ADD_PROJECT
        read -p "Who owns the website?  : " ADD_USER

        # Issue certificate for new domain name
        echo "${COLOUR_WHITE}>> issuing new SSL for $ADD_DOMAIN ${COLOUR_RESTORE}"
        certbot -n --nginx certonly -d ${ADD_DOMAIN} -d www.${ADD_DOMAIN}

        # Add new domain name to virtual host
        echo "${COLOUR_WHITE}>> adding ${ADD_DOMAIN} to virtual host conf ${COLOUR_RESTORE}"

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

        echo "Done."


    else
        break
    fi
}

# Load addUserPasswordDirectory function
addUserPasswordDirectory() {
    if ask "Are you sure you want to add a new user to a password protected directory?"; then
        read -p "User folder to edit  : " USER_FOLDER
        read -p "Username  : " USERNAME
        read -p "Password  : " PASSWORD
        echo '------------------------------------------------------------------------'
        echo 'Adding ${USERNAME} to ${USER_FOLDER} password directory'
        echo '------------------------------------------------------------------------'

        htpasswd -b /home/${USER_FOLDER}/.htpasswd ${USERNAME} ${PASSWORD}

        echo "User added successfully."

    else
        break
    fi
}

securePasswordDirectory() {
    if ask "Are you sure you want to toggle password directory?"; then
        read -p "Project name  : " PROJECT
        read -p "Owner  : " OWNER
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
        echo "${COLOUR_WHITE}>> Done.${COLOUR_RESTORE}"

    else
        break
    fi
}

# Load delete user function
deleteUser() {
    if ask "Are you sure you want to delete a user? This will delete the users home folder and MYSQL access"; then
        read -p "Enter the system user to delete  : " USER
        read -p "Confirm root MYSQL password  : " PASSWORD_MYSQL_ROOT
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
DROP USER 'yam_dbuser_${USER}_${DEL_PROJECT_NAME}'@'localhost';
DROP DATABASE yam_db_${USER}_${DEL_PROJECT_NAME};
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
            echo "Website removed."


        else
            echo "No website found. Skipping..."
        fi


    else
        break
    fi
}


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
echo 'WELCOME TO THE YAM SERVER CONFIGURATOR'


echo ''
echo 'What can I help you with today?'
echo ''
options=(
    "Setup a fresh Ubuntu server"
    "Add sudo user and SSH keys"
    "Enable or disable SSH password authentication"
    "Inject a MODX website from an external source"
    "Package MODX website for injection"
    "Add new development website"
    "Add new development website with Basesite"
    "Copy development website"
    "Map domain to website"
    "Add user to password directory"
    "Toggle password directory"
    "Delete user"
    "Delete website"
    "Quit"
)

select option in "${options[@]}"; do
    case "$REPLY" in
        1) setupServer ;;
        2) secureServer ;;
        3) securePasswords ;;
        4) installBasesite ;;
        5) packageWebsite ;;
        6) addVirtualhost ;;
        7) addVirtualhostBasesite ;;
        8) copyVirtualhost ;;
        9) addDomain ;;
        10) addUserPasswordDirectory ;;
        11) securePasswordDirectory ;;
        12) deleteUser ;;
        13) deleteWebsite ;;
        14) break ;;
    esac
done
