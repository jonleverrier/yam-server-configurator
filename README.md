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
