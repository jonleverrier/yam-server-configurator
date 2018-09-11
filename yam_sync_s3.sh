#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Sync S3
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4,
#+ Release:     0.0.1
#+----------------------------------------------------------------------------+

# EXAMPLE USAGE:
# /bin/bash yam_sync_s3.sh /local/path/ /s3/path/"

# Script requires s3cmd package to be installed and configured

# DEFAULT SETTINGS
BUCKET='yamdigital'

# VARIABLES THAT ARE PASSED IN TO THE SCRIPT...
FOLDER_LOCAL=$1
FOLDER_S3=$2

s3cmd sync --delete-removed --skip-existing $1 s3://$BUCKET$2
