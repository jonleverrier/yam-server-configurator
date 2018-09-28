#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Teleport
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4, 18.04
#+ Release:     1.1.0
#+----------------------------------------------------------------------------+

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
    echo 'YAM Teleport should be executed as the root user. Please switch to the'
    echo 'root user and try again'
    echo '------------------------------------------------------------------------'
    exit
fi

# Install Teleport
teleportInstall() {
    if ask "Are you sure you want to install Teleport?"; then
        echo ''
        echo '------------------------------------------------------------------------'
        echo 'Installing Teleport'
        echo '------------------------------------------------------------------------'
        echo ''

        # Make a teleport directory in the users home folder
        mkdir ~/teleport/ && cd ~/teleport/

        # Download Teleport
        wget -N http://modx.s3.amazonaws.com/releases/teleport/teleport.phar

        echo 'Install complete.'

    else
        break
    fi
}

# Profile Website
teleportProfile() {
    if ask "Are you sure you want to profile a website with Teleport?"; then
        read -p "Path to MODX core you want to profile  : " TELEPORT_PATH_CORE
        read -p "Name for profile  : " TELEPORT_LABEL_NAME
        read -p "Code for profile  : " TELEPORT_LABEL_CODE
        echo ''
        echo '------------------------------------------------------------------------'
        echo 'Profiling website...'
        echo '------------------------------------------------------------------------'
        echo ''

        php teleport.phar --action=Profile --name="${TELEPORT_LABEL_NAME}" --code=${TELEPORT_LABEL_CODE} --core_path=${TELEPORT_PATH_CORE} --config_key=config

        echo 'Profile complete.'

    else
        break
    fi
}

# Extract Website
teleportExtract() {
    if ask "Are you sure you want to extract a website with Teleport?"; then
        read -p "Name of profile you want to extract from?  : " TELEPORT_LABEL_NAME
        echo ''
        echo '------------------------------------------------------------------------'
        echo 'Extracting website...'
        echo '------------------------------------------------------------------------'
        echo ''

        php ~/teleport/teleport.phar --action=Extract --profile=profile/${TELEPORT_LABEL_NAME}.profile.json --tpl=phar://teleport.phar/tpl/complete.tpl.json

        echo 'Extraction complete.'

    else
        break
    fi
}

# Inject Website
teleportInject() {
    if ask "Are you sure you want to inject a website with Teleport?"; then
        read -p "Name of profile you want to inject in to?  : " TELEPORT_LABEL_NAME
        read -p "Name of transport package to inject?  : " TELEPORT_LABEL_PACKAGE
        read -p "Owner?  : " TELEPORT_LABEL_OWNER
        read -p "Project?  : " TELEPORT_LABEL_PROJECT
        echo ''
        echo '------------------------------------------------------------------------'
        echo 'Injecting website...'
        echo '------------------------------------------------------------------------'
        echo ''

        php ~/teleport/teleport.phar --action=Inject --profile=profile/${TELEPORT_LABEL_NAME}.profile.json --source=workspace/${TELEPORT_LABEL_PACKAGE}

        # Change permissions
        chown -R ${TELEPORT_LABEL_OWNER}:${TELEPORT_LABEL_OWNER} /home/${TELEPORT_LABEL_OWNER}/public/${TELEPORT_LABEL_PROJECT}

        echo 'Injection complete.'

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
echo 'YAM_TELEPORT.SH'


echo ''
echo 'What can I help you with today?'
echo ''
options=(
    "Install Teleport"
    "Profile a website"
    "Extract a website"
    "Inject a website"
    "Quit"
)

select option in "${options[@]}"; do
    case "$REPLY" in
        1) teleportInstall ;;
        2) teleportProfile ;;
        3) teleportExtract ;;
        4) teleportInject ;;
        5) break ;;
    esac
done
