#!/bin/bash

# If CONKY_DISABLE_NETWORK evaluates to true, then exit immediately.
if (( "$CONKY_DISABLE_NETWORK" )); then
    exit 0
fi

# Collecting most of our lists in advance.
# List of all interfaces
interfaces=$(ip a s | grep -e "^[0-9]*:"  | awk '{ print $2 }' | sed -e 's/://g' -e 's/@.*//g' | sort)
# Down interfaces
down_interfaces=$(ip a s | grep -e "^[0-9]*:" | grep -v -e "[<,]UP[,>]" | awk '{ print $2 }' | sed -e 's/://g' -e 's/@.*//g' | sort | tr '\n' ' ')
# Wireless interfaces
wireless_interfaces=$(find -L /sys/class/net/ -maxdepth 2 -name wireless 2> /dev/null | cut -d'/' -f5 | tr '\n' ' ')
# Bridges
bridges=$(find -L /sys/class/net/ -maxdepth 2 -name bridge 2> /dev/null | cut -d'/' -f5 | tr '\\\n' ' ')
# Bridge Members (to do this for a specific bridge, just add an argument to brctl. copy as needed)
bridge_members=$(brctl show | sed -e '/bridge name/d' -e 's/\t/\ /g' | awk '{ if(NF > 1){ $1="";$2="";$3="" } print $0 }' | tr '\n' ' ')

# List of interfaces to exclude from listing.
exclude_list="lo $CONKY_IGNORE_INTERFACES"
# Notes on exclude_list
## Space-delimited list. For example: "lo eth0 eth1"
## With the current approach, this would skip aliases entirely (e.g. blocking eth0 would block eth0:0),
##    and does not work in reverse since individual aliases are not checked (e.g. eth0:0 could not be specifically blocked)

. functions/common
. functions/network-labels

########################
########################
## Network Interfaces ##
########################
########################

#####################
# Gateway Discovery #
#####################

gateway_count=0
gateway_spacing=10 # For " Gateway: "
for ip in $(route -n | awk '{ if($3 == "0.0.0.0"){ print $2 } }' | sort -n); do
    gateway_count=$((gateway_count+1))

    if [ "$gateway_count" -ge 3 ]; then
        # Conky is set to only print "multiple" if there are 3 or more gateways present.
        # Break out and don't bother doing more processing that will not be displayed past 3.
        break
    fi

    tentative_length=$(expr length "$ip")

    # Note: May need to add a bit of extra padding for spaces to the left side of the below IF statement
    #   if I decide that you want to display more than 2 gateways before busting out the "multiple" label in the future.
    if [ "$(($tentative_length+$gateway_spacing))" -ge $characterWidthLimit ]; then
        gateway_spacing=$(($tentative_length+12))
        tentative_gateway="$tentative_gateway,\n             \${color #${colour_network_address}}$ip\$color"
    else
        gateway_spacing=$(($tentative_length+$gateway_spacing+2))
        tentative_gateway="$tentative_gateway, \${color #${colour_network_address}}$ip\$color"
    fi
done

if [ "$gateway_count" -gt "0" ]; then
    tentative_gateway="$(sed 's/^,\ //' <<< "$tentative_gateway")"
    
    if [ "$gateway_count" -ge 3 ]; then
        # Too many gateways to fit on a line.
        # Fall back to conky's default output of just saying "multiple".
        gateway="Gateways: multiple"
    elif [ "$gateway_count" -eq 1 ]; then
        gateway="Gateway: $tentative_gateway"
    else
        # Remaining case: More than one gateway, but under threshold (threshold is currently 3).
        gateway="Gateways: $tentative_gateway"
    fi
else
    # No gateways at all
    gateway="No Gateway"
fi

################################
# Header and Basic Information #
################################

printf "\${color #${colour_network}}\${font Neuropolitical:size=16:bold}Networking\$font\$color\$hr\n $gateway\n"

##############
# Interfaces #
##############

# List interfaces with details
for iface in ${interfaces}; do

    address=$(ip a s ${iface} 2> /dev/null | grep -om1 inet\ [^\/]*\/[0-9]* | cut -d' ' -f2)

    if [[ "${exclude_list}" =~ (^|\ )"${iface}"($|\ ) ]]; then
        # Ignore interfaces that we've been asked to exclude.
        continue
    elif [[ "${bridge_members}" =~ (^|\ )"${iface}"($|\ ) ]]; then
        # Do not list information for bridge members.
        # Bridge members will be shown under the parent interface.
        continue  
    elif [[ "${down_interfaces}" =~ (^|\ )"${iface}"($|\ ) ]] && ! [[ "${bridges}" =~ (^|\ )"${iface}"($|\ ) ]]; then
        # Do not list information for down interfaces, even if they have addresses
        # Bridges are the exception to this, since we still want to print members.
        continue
    elif ! ip a s ${iface} 2> /dev/null | grep -qwm1 "inet" && ! [[ "${bridges}" =~ (^|\ )"${iface}"($|\ ) ]] && ! ( [[ "${wireless_interfaces}" =~ (^|\ )"${iface}"($|\ ) ]] && iwconfig ${iface} 2>/dev/null | grep -q "Access Point: [A-F0-9]" ); then
        # Do not print other UP interfaces without addresses.
        # Printing in a separate list.
        # Bridges are the exception to this, since we still want to print members.
        # Wireless interfaces that are up AND associated to an AP are also the exception to this.
        #     Assumes that iwconfig won't give any output after "Access Point: " that starts with a hexidecimal character (capitals for alphabet letters)
        other_up_interfaces="${other_up_interfaces} ${iface}"
        continue
    fi

    # To confirm, if we are still in this loop we are dealing with an UP interface with an IP address
    if [ -z "$address" ] || [[ "$address" =~ \/ ]]; then
        printf " $(colour_interface ${iface}): $(colour_network_address "${address:-No Address}")"
    else
        # If the CIDR-form subnet mask is not already on IP output, then assume that it's a /32.
        # Most likely a tun_ interface.

        # If we can find a case in which the mask is something other than /32, then
        #     uncomment the commented code in this else statement, and adjust printf appropriately.
        # Get subnet mask for interface
        #unset display_mask
        #mask=$(ip a s ${iface} 2> /dev/null | grep -om1 inet\ [^\/]*\/[0-9]* | cut -d '/' -f 2)
        #if [ -n "${mask}" ]; then
        #    display_mask=/${mask}
        #fi
        printf " $(colour_interface ${iface}): $(colour_network_address "${address:-No Address}/32")"
    fi

    # Unset address-related variable for next loop.
    unset address

    #####################
    # Wireless Handling #
    #####################

    # If we're looking at a wireless interface, print extra connection information.
    if [ -d "/sys/class/net/${iface}/wireless" ]; then
        printf '\n'
        mac="$(iwconfig ${iface} 2> /dev/null | grep -om1 "Access Point:\ [^\ ]*" | cut -d' ' -f 3)"
        # Attempt to look for a cached copy of the wireless summary to save a bit of time on label/vendor lookups.
        if [ -f "$tempRoot/cache/wlan/$mac.txt" ]; then
            cat "$tempRoot/cache/wlan/$mac.txt"
        else
        wireless_report=$(printf "  ESSID: \${wireless_essid ${iface}}\\n  BSSID: ${mac} (\${wireless_link_qual ${iface}}%%%%)\n")
            location="$(__get_mac_specific_location "${mac}" 2> /dev/null)"
            if [ -n "${location}" ]; then
                wireless_report="${wireless_report}\n$(printf "  AP Location: %s\n" "$(shorten_string "${location}" 24)")"
            else
                # Try to resolve vendor instead
                vendor="$(__get_mac_vendor "${mac}" 2> /dev/null)"
                if [ -n "$vendor" ]; then
                    # Consider clipping output if necessary...
                    wireless_report="${wireless_report}\n$(printf "  AP Vendor: %s\n" "$(shorten_string "$vendor" 26)")"
                fi
            fi
            mkdir -p "$tempRoot/cache/wlan"
            printf "$wireless_report\n" | tee "$tempRoot/cache/wlan/$mac.txt"
        fi

        ###################
        # Bridge Handling #
        ###################
        
        # If we're looking at a bridge interface, print member information
    elif [ -d "/sys/class/net/${iface}/bridge" ]; then
        members=$(brctl show ${iface} | sed -e '/bridge name/d' -e 's/\t/\ /g' | tr -d \\n | awk '{ $1="";$2="";$3="";print $0 }')
        
        if [[ "${down_interfaces}" =~ (^|\ )"${iface}"($|\ ) ]]; then
            printf " (\${color #${colour_warning}}DOWN\${color})\n"
        else
            printf "\n"
        fi

        if [ $(wc -w <<< "$members") -gt "0" ]; then

            # "  Members:" is 10 characters
            characterIndex=10
    
            for member in ${members}; do
                ifaceLength=$(expr length "${member}")
                candidateLength=$(($characterIndex + $ifaceLength + 2))
                if [[ "${down_interfaces}" =~ (^|\ )"${member}"($|\ ) ]]; then
                    memberDown="(\${color #${colour_warning}}D\${color})"
                    candidateLength=$(($candidateLength+3))
                fi
                if [ $candidateLength -le $characterWidthLimit ]; then
                    member_list="${member_list} $(colour_interface ${member})$memberDown,"
                    characterIndex=$candidateLength
                else
                    member_list="${member_list}@    $(colour_interface ${member}),"
                    # Number of format characters on new line is 5 (4 spaces and a comma)
                    characterIndex=$(($ifaceLength+5))
                fi
                unset memberDown
            done
            printf "  Members:${member_list}\n" | sed -e 's/,$//' -e 's/@/\n/g'
        else
            printf "  No Members\n"
        fi
        # Clear member_list for next loop.
        unset member_list
    else
      printf "\n"
    fi

    # Print out any aliases that we've assigned to this interface.
    for alias_if in $(ip a s ${iface} | grep -oP "inet .*${iface}:\d*$" | awk '{ print $2","$NF}'); do
        printf "  $(colour_interface $(cut -d',' -f 2 <<< "$alias_if")): \${color #${colour_network_address}}%s\$color\n" "$(cut -d',' -f 1 <<< "$alias_if")"
    done

    if ! [[ "${down_interfaces}" =~ (^|\ )"${iface}"($|\ ) ]]; then
      printf "  Up: \${upspeed ${iface}}  Down: \${downspeed ${iface}}\n"
    fi
done

#######################
# Other UP Interfaces #
#######################

# List other interfaces that are up but do not have addresses.

# Interface hasn't been displayed previously (or is not deliberately excluded) if it does not match our pattern.

# " Other UP:" is 10 characters
characterIndex=10

for iface in ${other_up_interfaces}; do
    ifaceLength=$(expr length "${iface}")
    candidateLength=$(($characterIndex + $ifaceLength + 2))
    if [ $candidateLength -lt $characterWidthLimit ]; then
        up_display_list="${up_display_list} $(colour_interface ${iface}),"
        characterIndex=$candidateLength
    else
        up_display_list="${up_display_list}@    $(colour_interface ${iface}),"
        # Number of format characters on new line is 5 (4 spaces and a comma)
        characterIndex=$(($ifaceLength+5))
    fi
done

[ -n "${up_display_list}" ] && printf "  Other UP:${up_display_list}\n" | sed -e 's/,$//' -e 's/@/\n/g'

###################
# Down Interfaces #
###################

# "  Down:" is 7 characters
characterIndex=7

for iface in ${down_interfaces}; do
    if [[ "${bridge_members}" =~ (^|\ )"${iface}"($|\ ) ]] || [[ "${bridges}" =~ (^|\ )"${iface}"($|\ ) ]]; then
        # If the interfaces is also a bridge member, then skip
        # Downed bridge members are specially marked in the interface display, regardless of whether they're up or not.
        continue
    fi

    ifaceLength=$(expr length "${iface}")
    candidateLength=$(($characterIndex + $ifaceLength + 2))
    # Maybe it's the late hour that this was written at,
    #   but I cannot see what's different about the down interfaces
    #   that makes them need an extra hard-coded character
    if [ $candidateLength -le $characterWidthLimit ]; then
        down_display_list="${down_display_list} $(colour_interface ${iface}),"
        characterIndex=$candidateLength
    else
        down_display_list="${down_display_list}@    $(colour_interface ${iface}),"
        # Number of format characters on new line is 5 (4 spaces and a comma)
        characterIndex=$(($ifaceLength+5))
    fi
done

if [ -n "${down_display_list}" ]; then
  printf "  Down:${down_display_list}\n" | sed -e 's/,$//' -e 's/@/\n/g'
fi

##########################
##########################
## Incoming Connections ##
##########################
##########################

ephemeral_file="/proc/sys/net/ipv4/ip_local_port_range"
ephemeral_lower=$(cat "$ephemeral_file" | awk '{ print $1 }')
# Collect connections from netstat, then format with awk
connections_in=$(netstat -tun | grep ESTABLISHED  | awk '{ split($4,l,":"); split($5,r,":"); if(l[2] < '${ephemeral_lower}' && (r[2] > '${ephemeral_lower}' || $1 == "tcp") && ! (r[2] == 2049 && $1 == "tcp")){ print " ${color #'${colour_network_address}'}" r[1] "${color}->${color #'${colour_network_address}'}" l[1] "${color} ("$1"/"l[2]")" }; }' | sort -k2,2 -k3,3n |  uniq -c | grep --colour=never -v '127\.0\.0\.1' | awk '{ count=$1; $1=""; print $0; if (count > 1){ print "    Count: "count }}')
# A connection is considered incoming if the local port is below the lowest ephemeral port number AND the remote port is above the lowest ephemeral port number.
# TCP connections are somewhat excused and do not require the remote port to always be within the range.
# Excluding localhost connections, since it could get a bit rediculous.
# The special case with TCP/2049 is due to NFS mounting using a rediculously low local port (e.g. client's TCP/696 to server's TCP/2049).
# I *could* also filter out connections where the source address is the same as the destination address, but I choose not to at this time. Maybe some different colouring in the future?
# Confirming that UDP "connections" can actually show up and get printed out correctly, though I had to make a situation with nc to have an example to double-check.
# Reminder for re-testing (binds to udp/1234):
## Server (conky machine): nc -u -l 1234 > /dev/null
## Client: cat /dev/zero | nc -u any-address-but-localhost 1234 

if [ -n "$connections_in" ]; then
    # Print a separate header and report content.
    printf "\${color #${colour_network}}\${font Neuropolitical:size=16:bold}Incoming Connections\$font\$color\$hr\n${connections_in}"
fi
