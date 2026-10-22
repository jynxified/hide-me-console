#!/bin/bash
####################################################################################################
# hide.me VPN Connection Status Indicator
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
YELLOW="\e[33m"
NC="\e[0m"

# Name of the local hide.me service
HIDEME_SERVICE_NAME="hide.me"

# URL of the service for IP information lookup
IP_INFO_URL="https://ipinfo.io/what-is-my-ip"

# System tray icon files
ICON_PATH_LOCKED="/tmp/hideme_icon_locked.svg"
ICON_PATH_UNLOCKED="/tmp/hideme_icon_unlocked.svg"
ICON_PATH_WARNING="/tmp/hideme_icon_warning.svg"
ICON_PATH_UNKNOWN="/tmp/hideme_icon_unknown.svg"

# Last VPN connection state (-1 = unknown state)
LAST_VPN_STATE=-1

# The generic label displayed when the current WAN IP couldn’t be determined.
IP_UNKNOWN_LABEL="Current IP unknown"

# Log file path and line limit
LOG_PATH=~/.local/state/hide-me-status-indicator
LOG_FILE_NAME="hide-me-status-indicator.log"
LOG_SIZE_LIMIT_LINES=2000

####################################################################################################
# Functions
####################################################################################################

#
# Write a message to the application log file. Additionally, check whether the current log file has
# reached the specified size limit, archive it as a TAR archive if this is indeed the case, and start
# a fresh log file.
#
# Input parameters:
#  - [1] : The message to be logged.
# 
function log {

    # If the log file destination folder does not exist, it gets created.
    if [ ! -e "$LOG_PATH" ]
    then
        mkdir -p "$LOG_PATH"
    fi

    local log_file_path="$LOG_PATH/$LOG_FILE_NAME"

    # If the current log file reaches a certain size (in number of lines), it gets archived.
    if [ -e "$log_file_path" ]
    then
        local current_log_size=$(wc -l "$log_file_path" | sed 's/ .*$//g')
        if [[ $current_log_size -gt $LOG_SIZE_LIMIT_LINES ]]
        then
            local archived_log_path="$log_file_path""_$(date +%s)"
            mv -f "$log_file_path" "$archived_log_path" && tar -czf "$archived_log_path.gz" "$archived_log_path" >/dev/null 2>&1 && rm -f "$archived_log_path"
        fi
    fi

    # Write message to log file
    local message=$1
    
    local logTs=$(date +"%Y-%m-%d %H:%M:%S.$(date +%N | cut -c1-3)")
    echo "[$logTs] $message" >>"$log_file_path" 2>&1
}

#
# Check if there's a running session of the status indicator, and if so, kill it.
#
function killRunningSession {

    ps -ef | fgrep "hide-me-status-indicator" | fgrep -v "grep" | fgrep -v "$$" | awk '{print $2}' | while read pid
    do 
        kill -15 $pid >/dev/null 2>&1
        log "Removed running instance of the VPN connection status indicator with PID $pid"
        sleep 0.5
    done
    
    ps -ef | fgrep "yad" | fgrep "hideme" | fgrep -v "grep" | awk '{print $2}' | while read pid
    do
        kill -15 $pid >/dev/null 2>&1
        log "Removed running instance of yad with PID $pid"
        sleep 0.5
    done

}

#
# Generate the system tray icons that indicate whether a VPN connection is active or not.
#
function createIcons {

    if [ ! -e "$ICON_PATH_LOCKED" ] # The icon when a VPN connection is active.
    then
    
        log "Creating icon '$ICON_PATH_LOCKED'..."
    
        cat <<EOF > "$ICON_PATH_LOCKED"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#2ec27e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" fill="#2ec27e"></rect>
  <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="#2ec27e" stroke-width="2"></path>
</svg>
EOF
    fi

    if [ ! -e "$ICON_PATH_UNLOCKED" ] # The icon when no VPN connection is active.
    then

        log "Creating icon '$ICON_PATH_UNLOCKED'..."
    
        cat <<EOF > "$ICON_PATH_UNLOCKED"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#e01b24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" fill="#e01b24"></rect>
  <path d="M7 11V7a5 5 0 0 1 9.9-1" stroke="#e01b24" stroke-width="2"></path>
</svg>
EOF
    fi
    
    if [ ! -e "$ICON_PATH_WARNING" ] # The icon when the VPN connection status can’t be determined with certainty.
    then
    
        log "Creating icon '$ICON_PATH_WARNING'..."
    
        cat <<EOF > "$ICON_PATH_WARNING"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#FFFF00" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" fill="#FFFF00"></rect>
  <path d="M7 11V7a5 5 0 0 1 9.9-1" stroke="#FFFF00" stroke-width="2"></path>
</svg>
EOF
    fi
    
    if [ ! -e "$ICON_PATH_UNKNOWN" ] # The icon when the VPN connection status is unknown.
    then
    
        log "Creating icon '$ICON_PATH_UNKNOWN'..."
    
        cat <<EOF > "$ICON_PATH_UNKNOWN"
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#cccccc" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" fill="#cccccc"></rect>
  <path d="M7 11V7a5 5 0 0 1 9.9-1" stroke="#cccccc" stroke-width="2"></path>
</svg>
EOF
    fi
}

#
# Get current VPN (if connected to any)
#
# Return values:
#  - The name of the current VPN connection. An empty string if no VPN connection is currently active.
#
function getCurrentVpn {

	HIDEME_SERVICE_CLEANUP_PATTERN="s/^.*$(echo "$HIDEME_SERVICE_NAME" | sed 's/[.]/\\./g')@//g"
	echo -n "$(systemctl list-units --type=service --state=running | fgrep "$HIDEME_SERVICE_NAME" | sed -e "$HIDEME_SERVICE_CLEANUP_PATTERN" -e 's/\.service.*$//g')"
}

#
# Get current WAN IP with city, region, and nation.
#
# Return values:
#  - The current WAN IP, including geolocation information (city, region, and country/nation).
#
function getWanIpInformation {

    IP_INFO=$(curl --max-time 10 -L --max-redirs 5 -s $IP_INFO_URL)
    ERROR_CODE=$?
    
    if [[ "$ERROR_CODE" > 0 ]]
    then
        log "Failed to fetch WAN IP, error code $ERROR_CODE"
        echo -n "$IP_UNKNOWN_LABEL"
    elif [[ "$IP_INFO" == "" || $(echo "$IP_INFO" | fgrep -c "\"error\"") != 0 || $(echo "$IP_INFO" | fgrep -c "Moved Permanently") != 0 ]]
    then
        log "Failed to fetch WAN IP, response was not as expected: $IP_INFO"
        echo -n "$IP_UNKNOWN_LABEL"
    else
        WAN_IP=$(echo "$IP_INFO" | fgrep "\"ip\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
        IP_CITY=$(echo "$IP_INFO" | fgrep "\"city\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
        IP_REGION=$(echo "$IP_INFO" | fgrep "\"region\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_NATION=$(echo "$IP_INFO" | fgrep "\"country\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')

	    echo -n "$WAN_IP/$IP_CITY/$IP_REGION/$IP_NATION"
	fi
}

#
# Check the VPN connection status and display the corresponding icon in the system tray.
#
# State values:
#  -1 : Grey icon   = Default icon on startup, VPN connection status was not determined yet.
#   0 : Red icon    = No VPN connection is active.
#   1 : Green icon  = VPN connection is active.
#   2 : Yellow icon = VPN connection status could not be determined with certainty.
#
function refreshTrayIcon {

    local current_state=0

    if [[ "$(getCurrentVpn)" != "" ]]
    then
        current_state=1
    fi

    if [[ ($current_state -ne $LAST_VPN_STATE) || ($LAST_VPN_STATE == 2) ]]
    then
    
        if [[ ($current_state -ne $LAST_VPN_STATE) ]]
        then
            log "VPN connection status changed from $LAST_VPN_STATE to $current_state"
        fi
    
        local wan_info="$(getWanIpInformation)"
        if [[ "$wan_info" == "$IP_UNKNOWN_LABEL" ]]
        then
            current_state=2
        fi

        if [ "$current_state" -eq 0 ]
        then
            echo "icon:$ICON_PATH_UNLOCKED"
            echo "tooltip:❌ Not connected | $wan_info"
        elif [ "$current_state" -eq 1 ]
        then
            echo "icon:$ICON_PATH_LOCKED"
            echo "tooltip:🔒 Connected | $wan_info"
        elif [ "$current_state" -eq 2 ]
        then
            echo "icon:$ICON_PATH_WARNING"
            echo "tooltip:⚠️ Failed to fetch WAN IP information, VPN connection status uncertain"
        fi
        
        LAST_VPN_STATE=$current_state
    fi
}

####################################################################################################
# Main code
####################################################################################################

if [[ "$1" != "" ]]
then
    echo
    echo -e "${YELLOW}Woah, slow your roll, buddy...${NC}"
    echo
    echo -e "${YELLOW}This script runs strictly as a background service and neither requires nor supports any${NC}"
    echo -e "${YELLOW}startup parameters. For installation details, please refer to the hide.me/console README.${NC}"
    echo -e "${YELLOW}You'll find everything you need to know there—along with a few decent dad jokes and puns${NC}"
    echo -e "${YELLOW}to keep you entertained.${NC}"
    exit
fi

log "Launching status indicator (PID: $$)..."

# Check if another instance of the status indicator is currently running, and if so, kill it first.
killRunningSession

# Create tray icons.
createIcons

# Start yad as co-process and register it.
coproc YAD { yad --notification --listen --image="$ICON_PATH_UNKNOWN" --text="VPN status unknown" --menu="Quit!quit"; }

log "YAD coproc PID: $YAD_PID"

# Refresh tray icon every 2 seconds.
while kill -0 "$YAD_PID" 2>/dev/null
do
    refreshTrayIcon >&"${YAD[1]}"
    
    for ((i=0; i<20; i++))
    do
        kill -0 "$YAD_PID" 2>/dev/null || break
        sleep 0.1
    done
done

# Delete tray icons.
rm -f "$ICON_PATH_LOCKED" "$ICON_PATH_UNLOCKED" "$ICON_PATH_WARNING" "$ICON_PATH_UNKNOWN"
