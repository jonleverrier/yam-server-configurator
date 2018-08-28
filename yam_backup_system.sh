#!/bin/bash

# YAM BACKUP LOCAL
# by Jon Leverrier (jon@youandmedigital.com)
# Version 0.1

# To be used with cron, or run manually from the command line.

# Example usage;
# /bin/bash yam_backup_system.sh

# DEFAULT VARIABLES
YAM_DATEFORMAT_FULL=`date '+%Y-%m-%d'`
YAM_BACKUP_DURATION='+6'

# COLOURS
COLOUR_RESTORE=$(echo -en '\033[0m')
COLOUR_CYAN=$(echo -en '\033[00;36m')
COLOUR_WHITE=$(echo -en '\033[01;37m')

echo "${COLOUR_WHITE}>>${COLOUR_RESTORE}"
echo "${COLOUR_WHITE}>> Starting backup process for system ${COLOUR_RESTORE}"
echo "${COLOUR_WHITE}>>${COLOUR_RESTORE}"

# if backup folder exists skip, else add folder
if [ -d "/var/backups/nginx" ]; then
    echo "Backup folder already exists for /var/backups/nginx"
else
    # make backup dir for user
    mkdir -p /var/backups/nginx
fi

# if backup folder exists skip, else add folder
if [ -d "/var/backups/letsencrypt" ]; then
    echo "Backup folder already exists for /var/backups/letsencrypt"
else
    # make backup dir for user
    mkdir -p /var/backups/letsencrypt
fi

# if backup folder exists skip, else add folder
if [ -d "/var/backups/mysql" ]; then
    echo "Backup folder already exists for /var/backups/mysql"
else
    # make backup dir for user
    mkdir -p /var/backups/mysql
fi

# if backup folder exists skip, else add folder
if [ -d "/var/backups/ssh" ]; then
    echo "Backup folder already exists for /var/backups/ssh"
else
    # make backup dir for user
    mkdir -p /var/backups/ssh
fi

# if backup folder exists skip, else add folder
if [ -d "/var/backups/cron" ]; then
    echo "Backup folder already exists for /var/backups/cron"
else
    # make backup dir for user
    mkdir -p /var/backups/cron
fi

# tar nginx folder...
echo "${COLOUR_CYAN}-- Compressing nginx conf folder ${COLOUR_RESTORE}"
tar -czf /var/backups/nginx/nginxconf-${YAM_DATEFORMAT_FULL}.tar.gz /etc/nginx

# tar letsencrypt folder...
echo "${COLOUR_CYAN}-- Compressing letsencrypt folder ${COLOUR_RESTORE}"
tar -czf /var/backups/letsencrypt/letsencrypt-${YAM_DATEFORMAT_FULL}.tar.gz /etc/letsencrypt

# tar mysql folder...
echo "${COLOUR_CYAN}-- Compressing mysql folder ${COLOUR_RESTORE}"
tar -czf /var/backups/mysql/mysql-${YAM_DATEFORMAT_FULL}.tar.gz /var/lib/mysql

# tar ssh folder...
echo "${COLOUR_CYAN}-- Compressing ssh folder ${COLOUR_RESTORE}"
tar -czf /var/backups/ssh/ssh-${YAM_DATEFORMAT_FULL}.tar.gz /etc/ssh

# tar ssh folder...
echo "${COLOUR_CYAN}-- Compressing cron folder ${COLOUR_RESTORE}"
tar -czf /var/backups/cron/cron-${YAM_DATEFORMAT_FULL}.tar.gz /etc/cron.d

# delete old backups...
echo "${COLOUR_CYAN}-- Checking for old backups to delete ${COLOUR_RESTORE}"
if [ -d "/var/backups/nginx/" ]; then
    find /var/backups/nginx/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
fi

if [ -d "/var/backups/letsencrypt/" ]; then
    find /var/backups/letsencrypt/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
fi

if [ -d "/var/backups/mysql/" ]; then
    find /var/backups/mysql/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
fi

if [ -d "/var/backups/ssh/" ]; then
    find /var/backups/ssh/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
fi

if [ -d "/var/backups/cron/" ]; then
    find /var/backups/cron/* -daystart -mtime ${YAM_BACKUP_DURATION} -exec rm {} \;
fi

echo "${COLOUR_WHITE}>> Backup complete. ${COLOUR_RESTORE}"
