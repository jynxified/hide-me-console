#!/bin/bash
####################################################################################################
# hide.me/console Installer
# Written by @Jynx
#
# https://github.com/jynxified
# https://jynxified.wordpress.com
# jynxified@proton.me
# 
# Disclaimer:
# This script is provided "as is" without any warranty of any kind, either expressed or implied.
# Use it entirely at your own risk. The author (that's me) shall not be liable for any damages,
# data loss, system failures, or serious trouble you, your relatives, their neighbors or beloved
# pets might get into caused by the use or misuse of this script.
#
# Licensed under "CC BY-NC-ND 4.0" (https://creativecommons.org/licenses/by-nc-nd/4.0/).
####################################################################################################

# Text colors & styles
BOLD="\e[1m"
BOLD_BLUE="\e[1;34m"
BLUE="\e[34m"
RED="\e[31m"
BOLD_GREEN="\e[1;32m"
GREEN="\e[32m"
WHITE="\e[37m"
BOLD_MAGENTA="\e[1;35m"
MAGENTA="\e[35m"
BOLD_YELLOW="\e[1;33m"
YELLOW="\e[33m"
BLINK="\e[5m"
NC="\e[0m"

# Icons
ICON_MAIL="\U0001F4E7"
ICON_GITHUB="\u2699\uFE0F"
ICON_BLOG="\U0001F310"

# Destination paths and filenames
HIDE_ME_PATH=/opt/hide.me
DEST_PATH_CONSOLE=~/.local/bin/hide-me-console
DEST_PATH_STATUS_INDICATOR_LAUNCHER=~/.config/autostart

HIDE_ME_APP_FILENAME="hide.me"
HIDE_ME_SERVICE_FILENAME="hide.me@.service"
CONSOLE_FILENAME="hide-me-console.sh"
STATUS_INDICATOR_FILENAME="hide-me-status-indicator.sh"
STATUS_INDICATOR_LAUNCHER_FILENAME="hide-me-status-indicator.desktop"

# hide.me/console download URL
INSTALL_PACKAGE_URL="https://github.com/jynxified/hide-me-console/archive/refs/heads/main.zip"
INSTALL_PACKAGE_PATH="/tmp/hide-me-console.zip"
INSTALL_PACKAGE_UNCOMPRESSED_PATH="/tmp/hide-me-console/"

####################################################################################################
# Functions
####################################################################################################

# --- General installer functions ------------------------------------------------------------------

#
# Function called when the user cancels the installation using Ctrl+C.
#
function abortOnCtrlC() {
    echo
    echo
    echo -e "  ${YELLOW}***** Installation aborted. I'm off to Narnia...${NC}"
    exit 1
}
trap abortOnCtrlC INT

#
# Function called if an error occurs during installation.
#
function abortOnError {
    echo
    echo -e "  ${RED}I can't work like this, I'm an artist...${NC}"
    exit 1
}

#
# Checks whether the script was launched by a regular user or root. In the latter case, the script
# aborts. The installation must not be carried out as root. Yes, there are reasons for this. And no,
# I’m not writing them down here.   
# 
function assertCurrentUser {

    if [[ $(id -g) == 0 ]]
    then
        echo
        echo -e "  ${YELLOW}Sorry, but... no.${NC}"
        echo
        echo -e "  ${YELLOW}This script must NOT be run as root (which is exactly what you're trying to${NC}"
        echo -e "  ${YELLOW}do right now). Just try again, and then, perhaps, do it right. Otherwise I'm${NC}"
        echo -e "  ${YELLOW}more than happy to display this message to you again.${NC}"
        echo
        cat << "EOF"
        ( (
        ) )
      ........__
      |      |__|
      \      /
       '----'
EOF
        exit 1
    fi
}

#
# Generates a tab in the console output using the provided label. The label is converted entirely to
# uppercase with a space inserted between every letter. Why? Because it looks cooler. That's why.   
#
# Input parameters:
#  - [1] : The label for the tab.
#
function printTab {

    local tab_label=$(echo "$1" | tr '[:lower:]' '[:upper:]' | fold -w1 | paste -sd ' ')
    local tab_label_size=${#tab_label}
    local num_chars=$((tab_label_size+2))

    echo
    echo -en "     ┌"
    printf '─%.0s' $(seq 1 $num_chars)
    echo -e "┐"
    
    echo -e "     │ $tab_label │"
    
    echo -en " ────┘"
    printf "%${num_chars}s" ""
    echo -en "└"
    
    local padding_chars=$((80-num_chars-7))
    printf '─%.0s' $(seq 1 $padding_chars)
    echo
    echo
}

#
# Expects a yes/no response from the user to a specified question, and subtly insults them if they
# manage to mess up this relatively simple task.
#
# Input parameters:
#  - [1] : The question to be answered.
#
# Return values:
#  - 0 : User has selected no.
#  - 1 : User has selected yes.
#
function askYesNo {

    local question=$1
    echo -e "  ${YELLOW}$question (type 'y' for yes or 'n' for no)${NC}"
    
    local answer_index=0
    local insulting_answers=(
        "What exactly was unclear about 'y for yes or n for no'?"
        "C'mon, it's not THAT hard."
        "Now you’re just playing dumb on purpose!"
        "Maybe if you try putting in at least a tiny bit of effort?"
        "Is there anyone nearby who can help you out with this?"
        "Give it another shot, I believe in you."
        "Holy freakin' Jesus..."
        "Okay, okay, let’s just take it from the top..."
    )
    local answer_index=0
    local num_answers=${#insulting_answers[@]}
    
    while true
    do
        echo -en "  ${YELLOW} >${NC} "
        read PROCEED
        
        if [[ "$PROCEED" == "y" || "$PROCEED" == "Y" ]]
        then
            return 1;
        elif [[ "$PROCEED" == "n" || "$PROCEED" == "N" ]]
        then
            return 0;
        else
            echo -e "  ${YELLOW}${insulting_answers[answer_index]}${NC}"
            answer_index=$(( (answer_index + 1) % num_answers ))
            continue
        fi    
    done
}

#
# Display an installation step.
#
# Input parameters:
#  - [1] : The label of the installation step.
#
function startInstallStep {
    
    local step_label=$1
    echo -e "   ├──────── ${BOLD}$step_label${NC}"
}

#
# Display an installation step note.
#
# Input parameters:
#  - [1] : The note to be displayed.
#
function installStepNote {
    
    local note=$1
    echo -e "   │  ${BLUE}NOTE${NC}   $note"
}

#
# Display a success message for an installation step.
#
# Input parameters:
#  - [1] : The success message to be displayed.
#
function installStepSucceeded {
    local step_label=$1
    echo -e "   │  ${GREEN}OKAY${NC}   $step_label"
}

#
# Display a failure message for an installation step.
#
# Input parameters:
#  - [1] : The failure message to be displayed.
#
function installStepFailed {
    
    local failure_message=$1
    echo -e "   │  ${RED}FAIL${NC}   $failure_message"
    abortOnError
}

#
# Check whether the passed condition is true or false, and display a corresponding feedback.
#
# Input parameters:
#  - [1] : The condition to be checked.
#  - [2] : The success message to be displayed.
#  - [3] : The failure message to be displayed.
#
function assertInstallCondition {

    local cond_code=$1
    local success_message=$2
    local error_message=$3
    
    if [ "$cond_code" == 0 ] # true
    then
        installStepSucceeded "$success_message"
    else # false
        installStepFailed "$error_message"
    fi
}

#
# Check whether the last installation action was successful or not, and display a corresponding feedback.
#
# Input parameters:
#  - [1] : The action's return code to be checked.
#  - [2] : The success message to be displayed.
#  - [3] : The failure message to be displayed.
#
function assertInstallAction {

    local rc_code=$1
    local sucess_message=$2
    local error_message=$3

    if [ $rc_code != 0 ]
    then
        echo -e "   │  ${RED}FAIL${NC}   $error_message, error code ${YELLOW}$rc_code${NC}."
        abortOnError
    else
        echo -e "   │  ${GREEN}OKAY${NC}   $sucess_message"
    fi
}

#
# Display the start of an installation block.
#
# Input parameters:
#  - [1] : The label of the installation block.
#
function startInstallBlock {
    local block_label=$1
    echo -e "   ┌── $block_label"
    echo -e "   │"
}

#
# Display the end of an installation block.
#
function finishInstallBlock {
    echo -e "   └────────────────────────────────────────────────────────────────────────────"
    echo
}

#
# Display an in-progress indicator.
#
function showInProgressIndicator {
    printf "\r   │         ${YELLOW}${BLINK}In progress...${NC}\r"
}

#
# Download an installation archive, extract it, and switch into the extracted directory to continue working from there.
#
# Input parameters:
#  - [1] : The URL of the archive to be downloaded.
#  - [2] : The destination path for the downloaded archive.
#  - [3] : The path for the uncompressed data.
#
function downloadInstallPackage {
    
    local url=$1
    local download_dest_path=$2
    local uncompress_dest_path=$3
    
    startInstallStep "Fetching installation archive..."
    installStepNote "URL: ${BLUE}$url${NC}"
    installStepNote "Destination path: ${MAGENTA}$download_dest_path${NC}"
    
    if [ -e "$download_dest_path" ]
    then
        rm -f "$download_dest_path"
    fi
    
    showInProgressIndicator
    wget -q -O "$download_dest_path" "$url"
    assertInstallAction $? "Download succeeded." "Failed to download installation archive"

    showInProgressIndicator
    unzip -oq "$download_dest_path" -d "$uncompress_dest_path"
    assertInstallAction $? "Unpacking succeeded." "Failed to unpack installation archive"
    
    cd "$uncompress_dest_path"
}

#
# Removes all no longer required components of the installation process.
#
#  - [1] : The destination path for the downloaded installation archive.
#  - [2] : The path for the uncompressed installation data.
#
function cleanupInstallPackage {
    
    local download_dest_path=$1
    local uncompress_dest_path=$2
    
    startInstallStep "Cleaning up..."
    
    local cleanup_done=0
    
    if [ -e "$download_dest_path" ]
    then
        cleanup_done=1
        showInProgressIndicator
        rm -rf "$download_dest_path"
        assertInstallAction $? "Cleaned up: $download_dest_path" "Failed to clean up: $download_dest_path"
    fi
    
    if [ -e "$uncompress_dest_path" ]
    then
        cleanup_done=1
        showInProgressIndicator
        rm -rf "$uncompress_dest_path"
        assertInstallAction $? "Cleaned up: $uncompress_dest_path" "Failed to clean up: $uncompress_dest_path"
    fi
    
    if [[ $cleanup_done -eq 0 ]]
    then
        installStepSucceeded "Nothing to cleanup, everything is shiny and bright"
    fi
}

#
# Create a folder.
#
# Input parameters:
#  - [1] : The path and name of the folder that needs to be created.
#
function createFolder {

    local folder_path=$1

    startInstallStep "Creating folder"
    installStepNote "Path: ${MAGENTA}$folder_path${NC}"
    showInProgressIndicator

    if [ ! -e "$folder_path" ]
    then
        mkdir -p "$folder_path"
        assertInstallAction $? "Folder was successfully created." "Failed to create folder"
    else
        echo -e "   │  ${GREEN}OKAY${NC}   Folder already exists."
    fi
}

# --- hide.me/console specific installation steps --------------------------------------------------

function checkForInstallationPackage {

    if [ ! -e "./hide-me-console.sh" ]
    then
        downloadInstallPackage "$INSTALL_PACKAGE_URL" "$INSTALL_PACKAGE_PATH" "$INSTALL_PACKAGE_UNCOMPRESSED_PATH"
        cd "$(pwd)/hide-me-console-main"
        installStepNote "Changed working directory to: ${MAGENTA}$(pwd)${NC}"
    fi
}

function checkForHideMeInstallation {

    local hideMePath="$HIDE_ME_PATH/$HIDE_ME_APP_FILENAME"

    startInstallStep "Verifying hide.me installation"
    installStepNote "Path: ${MAGENTA}$hideMePath${NC}"
    showInProgressIndicator

    [ -e "$hideMePath" ]
    assertInstallCondition $? \
        "hide.me installation exists." \
        "No hide.me installation found. Maybe you should consider installing that one first: ${BLUE}https://hide.me/en/software/linux${NC}"
}

function installHideMeConsole {

    local sourcePath="$(pwd)/$CONSOLE_FILENAME"
    local consoleDestPath="$DEST_PATH_CONSOLE/$CONSOLE_FILENAME"

    startInstallStep "Installing hide.me/console script"
    installStepNote "Source path: ${MAGENTA}$sourcePath${NC}"
    installStepNote "Destination path: ${MAGENTA}$consoleDestPath${NC}"
    showInProgressIndicator

    cp "$sourcePath" "$consoleDestPath"
    assertInstallAction $? "Script was successfully copied." "Failed to copy script"

    showInProgressIndicator
    chmod +x "$consoleDestPath"
    assertInstallAction $? "Script was successfully marked as executable." "Failed to mark script as executable"
}

function adjustHideMeTimeouts {

    local hideMeServicePath="$HIDE_ME_PATH/$HIDE_ME_SERVICE_FILENAME"

    startInstallStep "Adjusting hide.me service timeouts"
    installStepNote "Path: ${MAGENTA}$hideMeServicePath${NC}"
    showInProgressIndicator

    sudo cp -f "$hideMeServicePath" "$hideMeServicePath.bak"
    assertInstallAction $? "Backup of service file was created." "Failed to create backup of service file"

    if [[ $(fgrep -c "TimeoutStartSec" $hideMeServicePath) == 0 ]]
    then
    
        sudo sed -i '/\[Service\]/a\TimeoutStartSec=30' "$hideMeServicePath"
        assertInstallAction $? "Start timeout was successfully added." "Failed to add start timeout"
        
    else
        echo -e "   │  ${GREEN}OKAY${NC}   Start timeout is already defined."
    fi

    if [[ $(fgrep -c "TimeoutStopSec" $hideMeServicePath) == 0 ]]
    then
    
        sudo sed -i '/\[Service\]/a\TimeoutStopSec=30' "$hideMeServicePath"
        assertInstallAction $? "Stop timeout was successfully added." "Failed to add stop timeout"
        
    else
        echo -e "   │  ${GREEN}OKAY${NC}   Stop timeout is already defined."
    fi
    
    sudo systemctl daemon-reload
    assertInstallAction $? "hide.me service was successfully reloaded." "Failed to reload hide.me service"
}

function installHideMeStatusIndicator {

    local sourcePath="$(pwd)/$STATUS_INDICATOR_FILENAME"
    local indicatorDestPath="$DEST_PATH_CONSOLE/$STATUS_INDICATOR_FILENAME"

    # Installing yad
    startInstallStep "Installing yad"
    
    if [ "$(whereis yad | sed 's/^.*://g' | wc -w)" == 0 ]
    then
        showInProgressIndicator
        sudo apt install -qq yad -y >/dev/null 2>&1
        assertInstallAction $? "yad was successfully installed." "Failed to install yad"
    else
        echo -e "   │  ${GREEN}OKAY${NC}   yad is already installed."
    fi

    # Installing script
    startInstallStep "Copying hide.me VPN status indicator script"
    installStepNote "Source path: ${MAGENTA}$sourcePath${NC}"
    installStepNote "Destination path: ${MAGENTA}$indicatorDestPath${NC}"

    showInProgressIndicator
    cp "$sourcePath" "$indicatorDestPath"
    assertInstallAction $? "Script was successfully copied." "Failed to copy script"

    showInProgressIndicator
    chmod +x "$indicatorDestPath"
    assertInstallAction $? "Script was successfully marked as executable." "Failed to mark script as executable"
    
    showInProgressIndicator
    
    source "$indicatorDestPath" &
    assertInstallAction $? "Script was successfully started." "Failed to start script"
}

function installHideMeStatusIndicatorLauncher {

    local indicatorDestPath="$DEST_PATH_CONSOLE/$STATUS_INDICATOR_FILENAME"
    local launcherDestPath="$DEST_PATH_STATUS_INDICATOR_LAUNCHER/$STATUS_INDICATOR_LAUNCHER_FILENAME"
    
    startInstallStep "Creating hide.me VPN status indicator launcher"
    installStepNote "Path: ${MAGENTA}$launcherDestPath${NC}"
    showInProgressIndicator
    
    
    
    (
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=Hide.me VPN Status Indicator"
        echo "Exec=$indicatorDestPath"
        echo "Hidden=false"
        echo "NoDisplay=false"
        echo "X-GNOME-Autostart-enabled=true" 
    ) >"$launcherDestPath"
        
    assertInstallAction $? "Launcher was successfully created." "Failed to create launcher"
}

####################################################################################################
# Main code
####################################################################################################

echo
cat << "EOF"
      ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
      ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
      ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
      ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
      ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
      ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
EOF
echo -e "     :::::.....       ${MAGENTA}hide${WHITE}.me${BOLD_BLUE}/${YELLOW}console${NC} + ${GREEN}VPN${NC} ${BOLD}Status Indicator${NC}      .....:::::"
echo -e "  =============================================================================="
echo -e "    ${ICON_MAIL}jynxified@proton.me | ${ICON_GITHUB} ${BLUE}github.com/jynxified${NC} | ${ICON_BLOG}${BLUE}jynxified.wordpress.com${NC}"
echo -e "  =============================================================================="

assertCurrentUser

printTab "INTRO"

echo -e "  Welcome to the ultra-slick, lightning-fast installer for the ${MAGENTA}hide${WHITE}.me${BOLD_BLUE}/${YELLOW}console${NC}."
echo
echo -e "  To make your life even easier than it already is, this script takes care of"
echo -e "  the final bits and pieces to set up the application and all its components."
echo -e "  So lean back and enjoy the ride. Please keep your arms and legs inside the"
echo -e "  vehicle at all times, and if you start feeling motion sick, hit the emergency"
echo -e "  stop button that doesn't exist. Thank you!"
echo
echo -e "  ${BOLD}Please note that any existing installation will be replaced by this installer.${NC}"
echo

askYesNo "Shall we start?"
RC_CODE=$?
if [[ $RC_CODE == 1 ]]
then
    echo
    echo -e "  Alright then, let's go!"
else
    echo
    echo -e "  So you triggered the script, but didn't actually want to run it? Alright then,"
    echo -e "  have it your way..."
    exit 0
fi

printTab "PREPARE"

echo -e "  Some setup steps need superuser rights. Please enter your superuser password"
echo -e "  below in case you get prompted, and if not: all the better, you’ve already got"
echo -e "  superuser rights. And yes, that’s necessary. No, it won’t break anything. And"
echo -e "  no, you’re not subscribing to a cooking magazine."
echo

SUPERUSER_GROUP_ID=$(sudo id -g)
ERROR_CODE=$?
if [[ $ERROR_CODE != 0 || $SUPERUSER_GROUP_ID != 0 ]]
then
    echo
    echo -e "  ${RED}You failed to authenticate as superuser. Great, just great. One might${NC}"
    echo -e "  ${RED}almost think you're not trying hard enough. No superuser, no installation,${NC}"
    echo -e "  ${RED}that's just how it is.${NC}"
    abortOnError
else
    echo
    echo -e "  ${GREEN}Okay, downloading malware...${NC}"
    echo -e "     Nah, just kidding \U1F609. All fine. We can proceed."
fi

printTab "INSTALL"

# Install hide.me/console
startInstallBlock "Installing ${MAGENTA}hide${WHITE}.me${BOLD_BLUE}/${YELLOW}console${NC}..."
    checkForHideMeInstallation
    checkForInstallationPackage
    createFolder "$DEST_PATH_CONSOLE"
    installHideMeConsole
    adjustHideMeTimeouts
finishInstallBlock

# Install hide.me VPN status indicator
startInstallBlock "Installing hide.me ${GREEN}VPN${NC} ${BOLD}Status Indicator${NC}..."
    installHideMeStatusIndicator
    createFolder "$DEST_PATH_STATUS_INDICATOR_LAUNCHER"
    installHideMeStatusIndicatorLauncher
    cleanupInstallPackage "$INSTALL_PACKAGE_PATH" "$INSTALL_PACKAGE_UNCOMPRESSED_PATH"
finishInstallBlock

# Finishing message
echo -e "  ${GREEN}Installation completed successfully, yay!${NC}"
echo
echo -e "  You can read up on everything else in the README."
