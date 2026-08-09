#!/bin/bash
####################################################################################################
# Interactive management console for hide.me VPN for Linux CLI
# Written by @Jynx
# https://github.com/jynxified
# jynxified@proton.me
# 
# History:
# 1.0.7 (2026-08-09) - Optimized IP information lookup and display.
# 1.0.6 (2026-07-30) - Location names no longer need to be case-sensitive, and entering partial names
#                      is now supported.
# 1.0.5 (2026-07-24) - Added action "locations"; added removal of "zombie" units; improved handling
#                      of locations with names that contain special characters; improved error handling;
#                      user experience and script feedback slightly improved.
# 1.0.1 (2026-07-09) - Added actions "shuffle", "next", and "dexit"; added help texts.
# 1.0.0 (2026-07-07) - Initial version.
#
# Disclaimer:
# This script is provided "as is" without any warranty of any kind, either expressed or implied.
# Use it entirely at your own risk. The author (that's me) shall not be liable for any damages,
# data loss, system failures, or serious trouble you, your relatives, their neighbours or beloved
# pets might get into caused by the use or misuse of this script.
#
# Licensed under "CC BY-NC-ND 4.0" (https://creativecommons.org/licenses/by-nc-nd/4.0/).
####################################################################################################

# Text colors
BOLD_BLUE="\e[1;34m"
BLUE="\e[34m"
RED="\e[31m"
GREEN="\e[32m"
WHITE="\e[37m"
BOLD_MAGENTA="\e[1;35m"
MAGENTA="\e[35m"
YELLOW="\e[33m"
BLINK="\e[5m"
NC="\e[0m"

# Name of the local hide.me service
HIDEME_SERVICE_NAME="hide.me"

# URL of the website where the hide.me VPN locations are listed
HIDEME_LOC_LIST_URL="https://hide.me/en/network"
# Element ID within the hide.me website containing VPN location information
HIDEME_LOC_ELEMENT_ID="ml-1 u-bold"
# Array of fetched hide.me VPN locations
HIDEME_LOC_LIST=()

# URL of the service for IP information lookup
IP_INFO_URL="https://ipinfo.io/what-is-my-ip"

####################################################################################################
# Functions
####################################################################################################

#
# Get current WAN IP with city, region, and nation.
#
function getWanIpInformation {

    IP_INFO=$(curl --max-time 10 -L --max-redirs 5 -s $IP_INFO_URL)
    ERROR_CODE=$?
    
    if [[ "$ERROR_CODE" > 0 ]]
    then
        echo -ne "${RED}Failed to look up IP information, error code $ERROR_CODE${NC}"
    fi
    
    if [[ "$IP_INFO" == "" || $(echo "$IP_INFO" | fgrep -c "\"error\"") != 0 || $(echo "$IP_INFO" | fgrep -c "Moved Permanently") != 0 ]]
    then
        echo -ne "${RED}Failed to look up IP information${NC}"
    fi
    
    WAN_IP=$(echo "$IP_INFO" | fgrep "\"ip\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
    IP_CITY=$(echo "$IP_INFO" | fgrep "\"city\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
    IP_REGION=$(echo "$IP_INFO" | fgrep "\"region\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	IP_NATION=$(echo "$IP_INFO" | fgrep "\"country\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')

	echo -ne "$WAN_IP${BLUE}/$IP_CITY${YELLOW}/$IP_REGION${MAGENTA}/$IP_NATION${NC}"
}

#
# Get current VPN (if connected to any)
#
function getCurrentVpn {

	HIDEME_SERVICE_CLEANUP_PATTERN="s/^.*$(echo "$HIDEME_SERVICE_NAME" | sed 's/[.]/\\./g')@//g"
	echo -n "$(systemctl list-units --type=service --state=running | fgrep "$HIDEME_SERVICE_NAME" | sed -e "$HIDEME_SERVICE_CLEANUP_PATTERN" -e 's/\.service.*$//g')"
}

#
# Get current VPN status
#
function getVpnStatus {

	CURRENT_VPN=$(getCurrentVpn)
	if [ "$CURRENT_VPN" != "" ]
	then
		echo -en "${GREEN}Connected${NC} to '${BLUE}$CURRENT_VPN${NC}' -> $(getWanIpInformation)"
	else
		echo -en "${RED}Not connected${NC} -> $(getWanIpInformation)"
	fi
}

#
# Get a list of all available hide.me VPN locations in alphabetical order. This list is fetched
# from the official hide.me website to ensure it's as up to date as possible.
#
function getVpnList {

    printf "\r ${YELLOW}${BLINK}Fetching VPN locations...${NC}\r"

	IFS_BACKUP=$IFS
	IFS=$'\n'
	LOC_CNTR=1
	HIDEME_LOC_CLEANUP_PATTERN="s/^.*$HIDEME_LOC_ELEMENT_ID\">//g"
	HIDEME_LOC_LIST=(`curl -s $HIDEME_LOC_LIST_URL | fgrep "$HIDEME_LOC_ELEMENT_ID" | sed -e "$HIDEME_LOC_CLEANUP_PATTERN" -e 's/,.*$//g' -e 's/ //g' | sed 'y/àáâãäåăèéêëìíîïòóôõöùúûüşçñ/aaaaaaaeeeeiiiiooooouuuuscn/' | sort`)
	for HIDEME_LOC in ${HIDEME_LOC_LIST[@]}
	do
	    echo -e "$(printf "[%2d]" $LOC_CNTR) ${BLUE}\"$HIDEME_LOC\"${NC}*"
	    ((LOC_CNTR++))
	done |xargs -L4 |column -t -S 5 -s $'*' | sed 's/^/   /g'

	IFS=$IFS_BACKUP
}

#
# Connect to a VPN location.
#
# Input parameters:
#  - [1] : Name or ID of the hide.me location to connect to
#
function connectVpn {

	NEW_VPN=$1
	if [[ "$NEW_VPN" =~ ^[0-9]+$ ]] # ID of location
	then
	    if [[ "$NEW_VPN" -ge 1 && "$NEW_VPN" -le ${#HIDEME_LOC_LIST[@]} ]]
	    then
	    	NEW_VPN=${HIDEME_LOC_LIST[$(expr $NEW_VPN - 1)]}
	    else
	    	echo -e " ${RED}Invalid location ID '$NEW_VPN', allowed range is [1,${#HIDEME_LOC_LIST[@]}].${NC}"
	    	NEW_VPN=""
	    fi
	fi

	if [ "$NEW_VPN" != "" ] # Name of location
	then
	    mapfile -d '' MATCHING_LOC_LIST < <(printf '%s\0' "${HIDEME_LOC_LIST[@]}" | grep -zi "$NEW_VPN")
	    
	    if [[ ${#MATCHING_LOC_LIST[@]} > 1 ]]
	    then
	        echo -e " ${YELLOW}The specified location name '${NEW_VPN}' is ambiguous, it matches ${#MATCHING_LOC_LIST[@]} locations. Please refine your input.${NC}"
	    elif [[ ${#MATCHING_LOC_LIST[@]} == 1 ]]
	    then

	        NEW_VPN="${MATCHING_LOC_LIST[0]}"
	        CURRENT_VPN="$(getCurrentVpn)"

	        if [ "$NEW_VPN" != "$CURRENT_VPN" ]
	        then
	    
	        	disconnectVpn
	        	SERVICE_NAME=$(systemd-escape "$NEW_VPN")
	            systemctl start "hide.me@$SERVICE_NAME"
	            ERROR_CODE=$?
	            if [ $ERROR_CODE != 0 ]
	            then
	                echo -e " ${RED}Failed to connect to '${BLUE}$NEW_VPN${RED}'${NC} (error code $ERROR_CODE)."
                    systemctl stop "hide.me@$SERVICE_NAME" # To clean up zombie units
	            fi
	            
	        else
	            echo -e " ${RED}You are already connected to '${BLUE}$NEW_VPN${RED}'.${NC}"
	        fi
	    else
	        echo -e " ${RED}Unknown location '${BLUE}$NEW_VPN${RED}'.${NC}"
	    fi
	fi
}

#
# Select a random VPN location and ensure it's not the same as as the currently used one (if any).
# The function does a limited number of retries (5) to select a unique, unused location, otherwise
# it returns an empty string.
#
function shuffleVpnLocation {

    CURRENT_LOC=$(getCurrentVpn)
    SELECTED_SHUFFLE_LOC=""
    SHUFFLE_RETRY_CNTR=0
    while (( $SHUFFLE_RETRY_CNTR < 5 ))
    do
        SHUFFLE_LOC_ID=$(( RANDOM % ${#HIDEME_LOC_LIST[@]} + 1 ))
        SHUFFLE_LOC=${HIDEME_LOC_LIST[$(expr $SHUFFLE_LOC_ID - 1)]}
        if [ "$SHUFFLE_LOC" != "$CURRENT_LOC" ]
        then
            SELECTED_SHUFFLE_LOC=$SHUFFLE_LOC
            break
        else
            ((SHUFFLE_RETRY_CNTR++))
        fi
    done

    echo -n "$SELECTED_SHUFFLE_LOC"
}

#
# Select the ID of the VPN location that is following the current one in the sorted list of locations.
# If no connection is established yet, the first location is picked. Also, if the last location of the
# list was reached, the ID switches back to the first one.
#
function nextVpnLocationId {

    NEW_LOC_ID=1

    CURRENT_LOC=$(getCurrentVpn)
    if [ "$CURRENT_LOC" != "" ]
    then
        for CURRENT_LOC_ID in "${!HIDEME_LOC_LIST[@]}"
        do
            if [[ "${HIDEME_LOC_LIST[$CURRENT_LOC_ID]}" == "$CURRENT_LOC" ]]
            then
                NEW_LOC_ID=$CURRENT_LOC_ID
                ((NEW_LOC_ID++))
                break
            fi
            
        done

        if [[ $NEW_LOC_ID < ${#HIDEME_LOC_LIST[@]} ]]
        then
            ((NEW_LOC_ID++))
        else
            NEW_LOC_ID=1
        fi
    fi
    
    echo -n "$NEW_LOC_ID"
}

#
# Disconnect the current VPN (if any)
#
function disconnectVpn {
	CURRENT_VPN="$(getCurrentVpn)";
	if [ "$CURRENT_VPN" != "" ]
	then
	    SERVICE_NAME=$(systemd-escape "$CURRENT_VPN")
		systemctl stop "hide.me@$SERVICE_NAME"
		ERROR_CODE=$?
		if [ $ERROR_CODE != 0 ]; then
		    echo -e " ${RED}Failed to disconnect from '${BLUE}$CURRENT_VPN${RED}'${NC} (error code $ERROR_CODE)."
		fi
	fi
}

#
# Prints a detailed help text for a specific action
#
# Input parameters:
#  - [1] : The action a help is requested for
#
function helpForAction {

    ACTION_NAME=$1

    if [ "$ACTION_NAME" == "c" ] || [ "$ACTION_NAME" == "connect" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: c[onnect] [ <location> | <id> ]${NC}"
        echo -e "    This action establishes a connection to a VPN location. It can be used with or without"
        echo -e "    a parameter. If used without a parameter, a random location from the list gets picked."
        echo -e "    The parameter is either the name of the desired location or its ID from the list. Names"
        echo -e "    don't have to be case-sensitive, entering partial names is supported as long as they"
        echo -e "    map to a single location."
        
    elif [ "$ACTION_NAME" == "d" ] || [ "$ACTION_NAME" == "disconnect" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: d[isconnect]${NC}"
        echo -e "    This action disconnects from the current VPN location. If no connection is established"
        echo -e "    yet, the action does nothing at all."
    elif [ "$ACTION_NAME" == "s" ] || [ "$ACTION_NAME" == "shuffle" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: s[huffle]${NC}"
        echo -e "    This action picks a random VPN location and establishes a connection to it. If there's"
        echo -e "    already an established connection to a location, it gets switched to the newly picked"
        echo -e "    location. The action ensures that not the same location gets picked and connected to again."
    elif [ "$ACTION_NAME" == "n" ] || [ "$ACTION_NAME" == "next" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: n[ext]${NC}"
        echo -e "    This action picks the location that follows the current one from the list and establishes"
        echo -e "    a connection to it. If no connection is established yet, the first location from the list"
        echo -e "    gets picked and connected to. If the last location from the list was reached, the first one"
        echo -e "    gets picked (round robin)."
    elif [ "$ACTION_NAME" == "i" ] || [ "$ACTION_NAME" == "info" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: i[nfo]${NC}"
        echo -e "    This action prints the VPN connection status, i.e. if a connection is currently established,"
        echo -e "    and how the WAN IP currently looks like."
    elif [ "$ACTION_NAME" == "l" ] || [ "$ACTION_NAME" == "locations" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: l[ocations]${NC}"
        echo -e "    This action refreshes the list of available VPN locations and displays it."
    elif [ "$ACTION_NAME" == "h" ] || [ "$ACTION_NAME" == "help" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: h[elp] <action>${NC}"
        echo -e "    This action prints a help text on, well, an action (obviously). Try one of the other actions"
        echo -e "    together with help. Makes more sense."
    elif [ "$ACTION_NAME" == "e" ] || [ "$ACTION_NAME" == "exit" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: e[xit]${NC}"
        echo -e "    This action exits the hide.me VPN console. If any VPN connection is current established, it"
        echo -e "    remains in that state and does not get disconnected. To manage it, just start the console again."
    elif [ "$ACTION_NAME" == "x" ] || [ "$ACTION_NAME" == "dexit" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: d[exit]${NC}"
        echo -e "    This action disconnects any currently established VPN connections and exits the hide.me VPN"
        echo -e "    console afterwards."
    elif [ "$ACTION_NAME" == "" ]
    then
        echo -e " ${RED}No action specified, please use 'help' with the name of an action you want to get help for.${NC}"
    else
        echo -e " ${RED}Unknown action '$ACTION_NAME', no help text available.${NC}"
    fi
}

####################################################################################################
# Main code
####################################################################################################

echo 
echo -e "----------------------------------------------------------------------------------"
echo -e "                             ${BOLD_BLUE}>>${NC}   ${MAGENTA}hide${WHITE}.me${BOLD_BLUE}/${YELLOW}console${BOLD_BLUE}   <<${NC}"
echo -e "----------------------------------------------------------------------------------"
echo -e "    Version 1.0.7 | ${YELLOW}@${BLUE}Jynx${NC} | jynxified@proton.me | ${BLUE}https://github.com/jynxified${NC}"
echo -e "----------------------------------------------------------------------------------"
echo
echo " Current VPN status : $(getVpnStatus)"
echo

echo " Available locations:"
echo

getVpnList

echo
echo " Available actions:"
echo

echo -e "   ${YELLOW} c | connect [<location>]${NC}\tConnect to VPN location"
echo -e "   ${YELLOW} d | disconnect${NC}\t\tDisconnect current VPN location"
echo -e "   ${YELLOW} s | shuffle${NC}\t\t\tConnect to a random VPN location"
echo -e "   ${YELLOW} n | next${NC}\t\t\tConnect to VPN location following the current one"
echo -e "   ${YELLOW} i | info ${NC}\t\t\tPrint info on connection status"
echo -e "   ${YELLOW} l | locations${NC}\t\tRefresh and show available VPN locations"
echo -e "   ${YELLOW} h | help <action>${NC}\t\tPrint help for console action"
echo -e "   ${YELLOW} e | exit${NC}\t\t\tExit VPN console"
echo -e "   ${YELLOW} x | dexit${NC}\t\t\tDisconnect current VPN location and exit console"
echo
while :
do
	read -p " #> " HIDEME_ACTION
	
	if [[ "$HIDEME_ACTION" =~ ^connect' ' ]] || [[ "$HIDEME_ACTION" =~ ^c' ' ]] || [ "$HIDEME_ACTION" == "connect" ] || [ "$HIDEME_ACTION" == "c" ]  # Action: connect
	then
	
		NEW_VPN=$(echo $HIDEME_ACTION | sed -E 's/^c(onnect)?[ ]?//g')
		if [ "$NEW_VPN" == "" ]
		then
		    NEW_VPN=$(shuffleVpnLocation)
		fi
		
		printf "\r ${YELLOW}${BLINK}Connecting...${NC}\r"
		connectVpn $NEW_VPN
		echo -e " $(getVpnStatus)"
		
	elif [ "$HIDEME_ACTION" == "disconnect" ] || [ "$HIDEME_ACTION" == "d" ] # Action: disconnect
	then
	
		CURRENT_VPN="$(getCurrentVpn)"
		if [ "$CURRENT_VPN" != "" ]
		then
			printf "\r ${YELLOW}${BLINK}Disconnecting...${NC}\r"
			disconnectVpn
			echo -e " $(getVpnStatus)"

		else
			echo -e " ${RED}Not connected to any VPN.${NC}"
		fi
	
	elif [ "$HIDEME_ACTION" == "shuffle" ] || [ "$HIDEME_ACTION" == "s" ] # Action: shuffle
	then
	
	    NEW_VPN=$(shuffleVpnLocation)
	    if [ "$NEW_VPN" != "" ]
	    then
	        printf "\r ${YELLOW}${BLINK}Connecting...${NC}\r"
		    connectVpn $NEW_VPN
	    else
	        echo -e " ${RED}Failed to shuffle a unique VPN location, try again or use a manual disconnect|connect.${NC}"
	    fi

	    echo -e " $(getVpnStatus)"

	elif [ "$HIDEME_ACTION" == "next" ] || [ "$HIDEME_ACTION" == "n" ] # Action: next
	then
	
	    NEW_VPN=$(nextVpnLocationId)
        printf "\r ${YELLOW}${BLINK}Connecting...${NC}\r"
	    connectVpn $NEW_VPN
	    echo -e " $(getVpnStatus)"
	
	elif [ "$HIDEME_ACTION" == "info" ] || [ "$HIDEME_ACTION" == "i" ] # Action: info
	then
	
		echo -e " $(getVpnStatus)"

	elif [ "$HIDEME_ACTION" == "locations" ] || [ "$HIDEME_ACTION" == "l" ] # Action: locations
	then
	
	    echo
		getVpnList
		echo
		
	elif [ "$HIDEME_ACTION" == "exit" ] || [ "$HIDEME_ACTION" == "e" ] # Action: exit
	then

		exit
		
	elif [ "$HIDEME_ACTION" == "dexit" ] || [ "$HIDEME_ACTION" == "x" ] # Action: dexit
	then
	
		CURRENT_VPN="$(getCurrentVpn)"
		if [ "$CURRENT_VPN" != "" ]
		then
			printf "\r ${YELLOW}${BLINK}Disconnecting...${NC}\r"
			disconnectVpn
		fi
		
		echo -e " $(getVpnStatus)"
		exit
	
	elif [[ "$HIDEME_ACTION" =~ ^help' ' ]] || [[ "$HIDEME_ACTION" =~ ^h' ' ]] || [ "$HIDEME_ACTION" == "help" ] || [ "$HIDEME_ACTION" == "h" ] # Action: help
	then
	
		HELP_ACTION=$(echo $HIDEME_ACTION | sed -E 's/^h(elp)?[ ]?//g')
		helpForAction $HELP_ACTION

	elif [ "$HIDEME_ACTION" == "" ] # No action was specified
	then

		echo -e " ${RED}No action inserted.${NC}"

	else # Unknown action

		echo -e " ${RED}Unknown action '$HIDEME_ACTION'.${NC}"

	fi
done
