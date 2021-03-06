
######################
 ####################
 # System Functions #
 ####################
######################

# Functions for working with hardware and system properties


# Unset battery directory from possible previous loop (as unlikely as it is to change from reload to reload).
unset __BATTERY_DIR

# Look for the first available battery.
# For the moment, assume only one battery.
for __BAT_NUM in $(seq 0 2); do
    if [ -f "/sys/class/power_supply/BAT${__BAT_NUM}/uevent" ]; then
        __BATTERY_DIR="/sys/class/power_supply/BAT${__BAT_NUM}"
        break
    fi
done
unset __BAT_NUM

if [ -n "$__BATTERY_DIR" ]; then
    alias battery='echo "Battery status: $(cat "$__BATTERY_DIR/capacity")% ($(cat "$__BATTERY_DIR/status"))"'
    alias battery-short="cat $__BATTERY_DIR/capacity"
else
    # For desktop machines.
    alias battery='echo "No battery detected..."'
    # Add a command so that getting the short battery is not just "not found".
    alias battery-short="echo 0"
fi

__is_laptop(){
    if [ -d /proc/acpi/battery/BAT* ] || [ -h /sys/class/power_supply/BAT* ]; then
        # For the moment, using the presence or lack of a battery
        #     as a lazy litmus test for the current system being a laptop or not.
        # Not a whole lot of desktops with batteries, but I'd still like to
        #     find a better method to use in the future...
        return 0
    fi
    return 1
}

# Make default memory display more verbose.
alias free='free -m -l -t' # show sizes in MB, with verbose information.


## Process Management ##

# Print out the time that each process has been running.
alias ps-time="ps axwo pid,etime,cmd"

get-env-var(){
    # Retrieve a specific environment variable from a process via procfs
    # Usage: get-env-var pid var-name

    local pid=$1
    local var=$2

    if ! grep -q "^[0-9]*$" <<< "$pid"; then
        error "$(printf "Invalid PID: ${Colour_Bold}%s${Colour_Off}" "$pid")" >&2
        notice "Usage: get-env-var pid var-name" >&2
        return 1
    fi

    if ! grep -iq "^[a-z0-9_]*$" <<< "$var"; then
        error "$(printf "Invalid variable name: ${Colour_Bold}%s${Colour_Off}" "$var")" >&2
        notice "Usage: get-env-var pid var-name" >&2
        return 1
    fi

    local envDir="/proc/$pid"
    local envFile="$envDir/environ"

    if [ ! -d "$envDir" ]; then
        error "$(printf "Process with PID of ${Colour_Bold}%d${Colour_Off} does not exist..." "$pid")" >&2
        return 3
    fi

    tr \\0 \\n 2> /dev/null < "$envFile" | grep "$var=" | cut -d"=" -f 2-
}

beep(){
  # Attempt to make a beep using the motherboard printer.
  # Useful for trying to announce that a task is done on a machine without other speakers.
  # This function will fail quietly if we have no motherboard speaker for whatever reason.
  if [ -w "/dev/tty1" ]; then
    # Default number
    local count=1
    local count_limit=25
    if grep -Pq "^\d{1,}$" <<< "$1" ; then
      if [ "$1" -le 0 ]; then
        local count=1
      elif [ "$1" -gt "$count_limit" ]; then
        # Cap out at a certain number of beeps to prevent accidental typos.
        # If you really want to beep over 15 times, call beep multiple times
        warning "$(printf "Capping beep count at $Colour_Bold%s$Colour_Off" "$count_limit")"
        local count=$count_limit
      else
        local count=$1
      fi
    fi
    local i=0
    while [ "$i" -lt "$count" ]; do
      echo -e "\07" > /dev/tty1
      local i=$(($i + 1))
      # Add a small beep to be able to tell individual beeps apart.
      sleep .1
    done
  else
    error "$(printf "$Colour_BIGreen%s$Colour_Off is not writable. Cannot attempt a beep." "/dev/tty1")"
    return 1
  fi
}
