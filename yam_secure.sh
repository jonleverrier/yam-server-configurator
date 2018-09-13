#!/bin/bash

#+----------------------------------------------------------------------------+
#+ YAM Server Secure
#+----------------------------------------------------------------------------+
#+ Author:      Jon Leverrier (jon@youandme.digital)
#+ Copyright:   2018 You & Me Digital SARL
#+ GitHub:      https://github.com/jonleverrier/yam-server-configurator
#+ Issues:      https://github.com/jonleverrier/yam-server-configurator/issues
#+ License:     GPL v3.0
#+ OS:          Ubuntu 16.0.4,
#+ Release:     0.0.1
#+----------------------------------------------------------------------------+

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
    echo "YAM Server Secure should be executed as the root user. Please switch to the root user and try again"
    exit
fi

# Load disable SSH password function
securePasswordsAllDisable () {
    if ask "Are you sure you want to disable SSH password authentication?"; then
        echo "${COLOUR_WHITE}>> removing SSH password authentication...${COLOUR_RESTORE}"
        sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
        sed -i "s/PubkeyAuthentication no/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/" /etc/ssh/sshd_config
        ssh-keygen -A
        service ssh restart
        echo "Done."
    else
        break
    fi
}

# Load enable SSH password function
securePasswordsAllEnable () {
    if ask "Are you sure you want to enable SSH password authentication?"; then
        echo "${COLOUR_WHITE}>> enabling SSH password authentication...${COLOUR_RESTORE}"
        sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/PubkeyAuthentication yes/PubkeyAuthentication no/" /etc/ssh/sshd_config
        sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
        ssh-keygen -A
        service ssh restart
        echo "Done."
    else
        break
    fi
}

# Load enable root login
securePasswordsRootEnable () {
    if ask "Are you sure you want to enable root login?"; then
        echo "${COLOUR_WHITE}>> enabling SSH root password authentication...${COLOUR_RESTORE}"
        sed -i "s/PermitRootLogin no/PermitRootLogin yes/" /etc/ssh/sshd_config
        ssh-keygen -A
        service ssh restart
        echo "Done."
    else
        break
    fi
}

# Load disable root login
securePasswordsRootDisable () {
    if ask "Are you sure you want to disable root login?"; then
        echo "${COLOUR_WHITE}>> removing SSH root password authentication...${COLOUR_RESTORE}"
        sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
        ssh-keygen -A
        service ssh restart
        echo "Done."
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
echo 'YAM_SECURE.SH'


echo ''
echo 'What can I help you with today?'
echo ''
passwordOptions=(
    "Disable password login"
    "Enable password login"
    "Disable root login"
    "Enable root login"
    "Quit"
)
select option in "${passwordOptions[@]}"; do
    case "$REPLY" in
        1) securePasswordsAllDisable ;;
        2) securePasswordsAllEnable ;;
        3) securePasswordsRootDisable ;;
        4) securePasswordsRootEnable ;;
        5) break ;;
    esac
done
