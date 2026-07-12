#!/bin/bash
# Management console for hide.me VPN
# Written by @Jynx
# 1.0.1 (2026-07-09) - Added actions "shuffle", "next", and "dexit"; added help texts
# 1.0.0 (2026-07-07) - Initial version

# Text colors
BOLD_BLUE="\e[1;34m"
BLUE="\e[34m"
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
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

#
# Functions
#

# Get current WAN IP with region and country
function getWanIpAndRegion {
	WAN_IP=$(curl -s https://api.ipify.org)
	IP_REGION=$(curl -s ipinfo.io/$WAN_IP/region)
	IP_COUNTRY=$(curl -s ipinfo.io/$WAN_IP/country)
	echo -ne "${MAGENTA}$WAN_IP${YELLOW}/$IP_REGION${NC}/$IP_COUNTRY"
}

# Get current VPN (if connected to any)
function getCurrentVpn {
	HIDEME_SERVICE_CLEANUP_PATTERN="s/^.*$(echo "$HIDEME_SERVICE_NAME" | sed 's/[.]/\\./g')@//g"
	echo -n "$(systemctl list-units --type=service --state=running | fgrep "$HIDEME_SERVICE_NAME" | sed -e "$HIDEME_SERVICE_CLEANUP_PATTERN" -e 's/\.service.*$//g')"
}

# Get current VPN status
function getVpnStatus {
	CURRENT_VPN=$(getCurrentVpn)
	if [ "$CURRENT_VPN" != "" ]
	then
		echo -en "${GREEN}Connected${NC} to '${BLUE}$CURRENT_VPN${NC}' -> $(getWanIpAndRegion)"
	else
		echo -en "${RED}Not connected${NC} -> $(getWanIpAndRegion)"
	fi
}

# Get a list of all available hide.me VPN locations in alphabetical order. This list is fetched
# from the official hide.me website to ensure it's as up to date as possible.
function getVpnList {
	IFS_BACKUP=$IFS
	IFS=$'\n'
	LOC_CNTR=1
	HIDEME_LOC_CLEANUP_PATTERN="s/^.*$HIDEME_LOC_ELEMENT_ID\">//g"
	HIDEME_LOC_LIST=(`curl -s $HIDEME_LOC_LIST_URL | fgrep "$HIDEME_LOC_ELEMENT_ID" | sed -e "$HIDEME_LOC_CLEANUP_PATTERN" -e 's/,.*$//g' -e 's/ //g' | sort`)
	for HIDEME_LOC in ${HIDEME_LOC_LIST[@]}
	do
	    echo -e "$(printf "[%2d]" $LOC_CNTR) ${BLUE}\"$HIDEME_LOC\"${NC}*"
	    ((LOC_CNTR++))
	done |xargs -L4 |column -t -S 5 -s $'*' | sed 's/^/   /g'

	IFS=$IFS_BACKUP
}

# Connect to a VPN location
# param 1: Name or ID of the hide.me location to connect to
function connectVpn {
	NEW_VPN=$1
	if [[ "$NEW_VPN" =~ ^[0-9]+$ ]] # ID of location
	then
	    if [[ "$NEW_VPN" -ge 1 && "$NEW_VPN" -le ${#HIDEME_LOC_LIST[@]} ]]
	    then
	    	NEW_VPN=${HIDEME_LOC_LIST[$(expr $NEW_VPN - 1)]}
	    else
	    	echo -e " ${RED}Invalid location ID '$NEW_VPN', allowed range is [1,${#HIDEME_LOC_LIST[@]}]${NC}"
	    	NEW_VPN=""
	    fi
	fi

	if [ "$NEW_VPN" != "" ]
	then
	    if printf '%s\0' "${HIDEME_LOC_LIST[@]}" | grep -qFxz "$NEW_VPN"
	    then
	    	disconnectVpn
	        systemctl start hide.me@$NEW_VPN
	        if [ $? != 0 ]; then
	            echo -e " ${RED}Failed to connect to '${BLUE}$NEW_VPN${RED}'${NC} (error code $?)"
	        fi
	    else
	        echo -e " ${RED}Unknown location '${BLUE}$NEW_VPN${RED}'${NC}"
	    fi
	fi
}

# Select a random VPN location and ensure it's not the same as as the currently used one (if any).
# The function does a limited number of retries (5) to select a unique, unused location, otherwise
# it returns an empty string.
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

# Select the ID of the VPN location that is following the current one in the sorted list of locations.
# If no connection is established yet, the first location is picked. Also, if the last location of the
# list was reached, the ID switches back to the first one.
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

# Disconnect the current VPN (if any)
function disconnectVpn {
	CURRENT_VPN=$(getCurrentVpn);
	if [ "$CURRENT_VPN" != "" ]
	then
		systemctl stop hide.me@$CURRENT_VPN
		if [ $? != 0 ]; then
		    echo -e " ${RED}Failed to disconnect from '${BLUE}$CURRENT_VPN${RED}'${NC} (error code $?)"
		fi
	fi
}

# Prints a detailed help text for a specific action
# param 1: The action a help is requested for
function helpForAction {

    ACTION_NAME=$1

    if [ "$ACTION_NAME" == "c" ] || [ "$ACTION_NAME" == "connect" ]
    then
        echo -e " ${BOLD_MAGENTA}Syntax: c[onnect] [ <location> | <id> ]${NC}"
        echo -e "    This action establishes a connection to a VPN location. It can be used with or without"
        echo -e "    a parameter. If used without a parameter, a random location from the list gets picked."
        echo -e "    The parameter is either the exact name of the desired location or its ID from the list."
        
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

#
# Main code
#

echo 
echo -e "${BOLD_BLUE}-------------------------------------------------------${NC}"
echo -e "${BOLD_BLUE}----::::       >>   ${MAGENTA}hide${WHITE}.me${BOLD_BLUE}/${YELLOW}console${BOLD_BLUE}   <<       ::::----${NC}"
echo -e "${BOLD_BLUE}-------------------------------------------------------${NC}"
echo -e "                                  | 1.0.1 | ${BLUE}by ${YELLOW}@${BLUE}Jynx${NC}"
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
