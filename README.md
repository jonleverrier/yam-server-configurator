# yam-server-configurator
Configure and manage a VPS to host multiple MODX websites running off a LEMP stack on Ubutnu 16.04.4 x64 from Digital Ocean. Work in progress.

### yam_setup.sh

Example usage:
Once you have logged into your server via SSH, type the following into the command line
```
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_setup.sh
```

Then run as root user:
```
/bin/bash yam_setup.sh
```
You will then be prompted to choose from the following options:
* Setup a fresh Ubuntu server
* Add sudo user and SSH keys
* Enable or disable SSH password authentication
* Inject a MODX website from an external source
* Package MODX website for injection
* Add new development website
* Add new development website with Basesite
* Copy development website
* Map domain to website
* Add user to password directory
* Toggle password directory
* Delete user
* Delete website
* Quit

If you choose to setup a server, the script will installs and configure NGINX, MariaDB, PHP7.1 FPM, Certbot (Let's Encrypt), PhpMyAdmin, Fail2Ban with UFW, php-imagick, htop, zip, unzip, Digital Ocean agent, s3cmd, nmap, yam_backup_local.sh, yam_backup_s3.sh, yam_sync_s3.sh and yam_backup_system.sh

The script also configures ssh keys, root and sudo users, time zone for server and mysql, skeleton directory,
log rotation, ssl auto renewal, UFW, default error pages, local backup of core system folders, local backup of user web folders, S3 backup of core system folders, sessions, securing MODX, S3 backup of user web folders

Whilst this script installs Amazon s3cmd, you'll have to run setup yourself. Was very quick todo, hence not adding it to the build script (s3cmd powers backups to AWS).

### yam_backup_local.sh

To be used with cron, or run manually from the command line.

Example usage; backup websites that live in /home/jamesbond/:
```
/bin/bash yam_backup_local.sh jamesbond
```

This scripts presumes your user directory is organised like the following;
```
/home/user/public/website1
/home/user/public/website2
/home/user/public/website3
```

### yam_backup_s3.sh

Example usage:
```
/bin/bash yam_backup_s3.sh user s3_server_folder_name
```
There is also a global variable `PATH_BACKUP` that can be edited to build any
S3 URL.

### yam_backup_system.sh

To be used with cron, or run manually from the command line.

Example usage;
```
/bin/bash yam_backup_system.sh
```

### yam_sync_s3.sh
Example usage:
```
/bin/bash yam_sync_s3.sh /local/path/ /s3/path/
```
