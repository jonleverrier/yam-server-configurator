# yam-server-configurator
Setup an Ubutnu 16.04.4 x64 VPS and LEMP stack from Digital Ocean. Host and manage multiple MODX websites.

Designed to be used on a fresh server with nothing installed apart from Ubutnu.

## yam_setup.sh

To run the setup script, you will need to login to your server as the root user via SSH. Once you're logged in, type the following into the command line:

```
cd /usr/local/bin
```
Followed by:

```
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_setup.sh
```
At this point you will want to customise the variables at the top of the script before running it. Type the following into the command line to edit the script:
```
nano /usr/local/bin/yam_setup.sh
```

Then type the following command to load it:
```
/bin/bash yam_setup.sh
```
You will then be prompted to choose from the following options:
1. Setup a fresh Ubuntu server
2. Add sudo user and SSH keys
3. Enable or disable SSH password authentication
4. Quit

If you choose to setup a fresh server, the script will installs and configure NGINX, MariaDB, PHP7.1 FPM, Certbot (Let's Encrypt), PhpMyAdmin, Fail2Ban with UFW, php-imagick, htop, zip, unzip, Digital Ocean agent, s3cmd, nmap, yam_backup_local.sh, yam_backup_s3.sh, yam_sync_s3.sh and yam_backup_system.sh

The script also configures ssh keys, root and sudo users, time zone for server and mysql, skeleton directory,
log rotation, ssl auto renewal, UFW, default error pages, local backup of core system folders, local backup of user web folders, S3 backup of core system folders, sessions, securing MODX, S3 backup of user web folders

_Whilst this script installs Amazon s3cmd, you'll have to run setup yourself. Was very quick todo, hence not adding it to the build script (s3cmd powers backups to AWS)._

## yam_manage.sh

When you are finished with setup, you can logout and login as your new sudo user. Customise the variables at the top of the yam_manage.sh script by typing the following into the command line :
```
nano /usr/local/bin/yam_manage.sh
```
Once you're ready, type the following to load the script:

```
/bin/bash yam_manage.sh
```
You will then be prompted to choose from the following options:
1. Inject a MODX website from an external source
2. Package MODX website for injection
3. Add new development website
4. Add new development website with Basesite
5. Copy development website
6. Map domain to website
7. Add user to password directory
8. Toggle password directory
9. Delete user
10. Delete website

## Utility Scripts

Make sure you check these files for variables that may need customising.

### yam_backup_local.sh

To be used with cron, or run manually from the command line.

Example usage; backup websites that live in /home/jamesbond/:
```
/bin/bash yam_backup_local.sh jamesbond
```

This scripts presumes yam_setup.sh setup your server. Therefore your user directory is organised like the following;
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
