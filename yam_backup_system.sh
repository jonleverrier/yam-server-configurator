#!/bin/bash

# YAM BACKUP LOCAL
# by Jon Leverrier (jon@youandmedigital.com)
# Version 0.1

# To be used with cron, or run manually from the command line.

# Example usage;
# /bin/bash yam_backup_system.sh

# DEFAULT VARIABLES
DATE_FULL=`date '+%Y-%m-%d'`
BACKUP_DURATION_TIME='+6'

# COLOURS
RESTORE=$(echo -en '\033[0m')
CYAN=$(echo -en '\033[00;36m')
WHITE=$(echo -en '\033[01;37m')

echo "${WHITE}>>${RESTORE}"
echo "${WHITE}>> Starting backup process for system ${RESTORE}"
echo "${WHITE}>>${RESTORE}"

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
echo "${CYAN}-- Compressing nginx conf folder ${RESTORE}"
tar -czf /var/backups/nginx/nginxconf-$DATE_FULL.tar.gz /etc/nginx

# tar letsencrypt folder...
echo "${CYAN}-- Compressing letsencrypt folder ${RESTORE}"
tar -czf /var/backups/letsencrypt/letsencrypt-$DATE_FULL.tar.gz /etc/letsencrypt

# tar mysql folder...
echo "${CYAN}-- Compressing mysql folder ${RESTORE}"
tar -czf /var/backups/mysql/mysql-$DATE_FULL.tar.gz /var/lib/mysql

# tar ssh folder...
echo "${CYAN}-- Compressing ssh folder ${RESTORE}"
tar -czf /var/backups/ssh/ssh-$DATE_FULL.tar.gz /etc/ssh

# tar ssh folder...
echo "${CYAN}-- Compressing cron folder ${RESTORE}"
tar -czf /var/backups/cron/cron-$DATE_FULL.tar.gz /etc/cron.d

# delete old backups...
echo "${CYAN}-- Checking for old backups to delete ${RESTORE}"
if [ -d "/var/backups/nginx/" ]; then
    find /var/backups/nginx/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
fi

if [ -d "/var/backups/letsencrypt/" ]; then
    find /var/backups/letsencrypt/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
fi

if [ -d "/var/backups/mysql/" ]; then
    find /var/backups/mysql/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
fi

if [ -d "/var/backups/ssh/" ]; then
    find /var/backups/ssh/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
fi

if [ -d "/var/backups/cron/" ]; then
    find /var/backups/cron/* -daystart -mtime ${BACKUP_DURATION_TIME} -exec rm {} \;
fi

echo "${WHITE}>> Backup complete. ${RESTORE}"
