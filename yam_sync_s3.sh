#!/bin/bash

# YAM SNYC to Amazon S3
# by Jon Leverrier (jon@youandme.digital)
# Version 0.1

# EXAMPLE USAGE:
# /bin/bash yam_sync_s3.sh /local/path/ /s3/path/"

# Script requires s3cmd package to be installed and configured

# DEFAULT SETTINGS
BUCKET='yamdigital'

# VARIABLES THAT ARE PASSED IN TO THE SCRIPT...
FOLDER_LOCAL=$1
FOLDER_S3=$2

s3cmd sync --delete-removed --skip-existing $1 s3://$BUCKET$2
