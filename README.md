# yam-server-configurator
Setup an Ubutnu 16.04.4 or 18.04 x64 VPS from Digital Ocean. Host and manage multiple MODX websites running on a LEMP stack.

## Before you begin...

These scripts are designed to be used on a fresh server with _nothing else installed_ apart from Ubutnu. You will also need to have a domain name pointed to your servers IP address and configured like the following example:

Type | Hostname | Value | TTL
------------ | ------------- | ------------- | -------------
CNAME | `*.dev.mymodxhosting.com` | is an alias of `dev.mymodxhosting.com` | 43200
A | `dev.mymodxhosting.com` | directs to `<server ip>` | 600

During setup, you will be asked for the URL to your default website and phpmyadmin installation in order to issue SSL certificates for those domains. Example values are:
* Domain for default website: dev.mymodxhosting.com
* Domain for phpmyadmin: pma.user.dev.mymodxhosting.com

## yam_setup.sh

To run the setup script, you will need to login to your server as the root user via SSH. Once you're logged in, type the following into the command line:

```
cd /usr/local/bin
wget -N https://raw.githubusercontent.com/jonleverrier/yam-server-configurator/master/yam_setup.sh
```

At this point you will want to customise the variables at the top of the script before running it. Type the following into the command line to edit the script:
```
nano /usr/local/bin/yam_setup.sh
```

Then once you are done, type the following command to load the script:
```
/bin/bash yam_setup.sh
```
You will then be prompted to choose from the following options:
1. Setup a fresh Ubuntu server
2. Quit

If you choose to setup a fresh server, the script will installs and configure NGINX, MariaDB, PHP7.1 FPM, Certbot (Let's Encrypt), PhpMyAdmin, Fail2Ban with UFW, php-imagick, htop, zip, unzip, Digital Ocean agent, s3cmd, nmap and additional YAM scripts.

The script also configures root and sudo users, time zone for server and mysql, skeleton directory, log rotation, ssl auto renewal, UFW, default error pages, local backup of core system folders, local backup of user web folders, S3 backup of core system folders, sessions, securing MODX and S3 backup of user web folders.

## yam_secure.sh

When you are finished with setup, you can logout and login as your new sudo user. To run the script, you will need to `su root` before running it. Type the following to load the script:

```
/bin/bash yam_secure.sh
```
You will then be prompted to choose from the following options:
1. Setup sudo and root user with keys
2. Disable password login
3. Enable password login
4. Disable root login
5. Enable root login
6. Quit

## yam_manage.sh

Like yam_setup.sh, customise the variables at the top of the yam_manage.sh script before running:
```
nano /usr/local/bin/yam_manage.sh
```

Once you're ready, type the following to load the script:

```
/bin/bash yam_manage.sh
```
You will then be prompted to choose from the following options:
1. Add new development website
2. Install a Basesite
3. Add new development website with Basesite
4. Package up website for injection
5. Copy development website
6. Map domain to development website
7. Add user to password directory
8. Toggle password directory
9. Delete user
10. Delete website
11. Quit

## Utility Scripts

Make sure you check these files for variables that may need customising.

Whilst yam_setup.sh installs Amazon s3cmd, you'll have to run `s3cmd --configure` in order to add your Amazon S3 credentials before your backups will begin to sync.

### yam_backup_local.sh

To be used with cron, or run manually from the command line.

Example usage; backup all websites that live in /home/jamesbond/:
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

## A note about security...

These scripts attempt to setup and secure your server above and beyond simple installation of PHP, NGINX and MYSQL.

### Sudo User
yam_setup.sh will create a sudo user. This user has SFTP and SSH access. You have the ability in yam_secure.sh to disable the `root` user, password logins and setup SSH keys - please do this!

By default, bash history is disabled and password fields during yam_setup.sh, yam_secure.sh and yam_manage.sh are hidden, however it may still be possible for somebody with access to your server already to view this information.

### MYSQL & Firewall
During setup, MYSQL will run through a manual secure installation process.

yam_setup.sh installs fail2ban which works with UFW to block IP addresses from attacking your server.

### Standard User Access

Standard users have access to SFTP but not SSH and are contained to their own home folder via chroot. Access to troublesome PHP functions has been restricted. A unique username and database name is used on a per project basis. All development websites are password protected by default and issued an automatic SSL.

These scripts are designed to get you setup quickly. Ultimately, security is an ongoing process and needs to be reviewed regularly. Do not install if you have any doubts.

If you're looking for something that scales, try [Puppet](https://www.digitalocean.com/community/tutorials/how-to-install-puppet-4-in-a-master-agent-setup-on-ubuntu-14-04).
