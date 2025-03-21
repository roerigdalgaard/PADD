#!/usr/bin/env bash
# shellcheck disable=SC1091

# PADD

# A more advanced version of the chronometer provided with Pihole

# SETS LOCALE
# Issue 5: https://github.com/jpmck/PADD/issues/5
# Updated to en_US to support
# export LC_ALL=en_US.UTF-8 > /dev/null 2>&1 || export LC_ALL=en_GB.UTF-8 > /dev/null 2>&1 || export LC_ALL=C.UTF-8 > /dev/null 2>&1
LC_ALL=C
LC_NUMERIC=C

############################################ VARIABLES #############################################

# VERSION
padd_version="v4.0.MRD"
padd_version_latest="v4.0.MRD"
padd_build="(72)"


# Settings for Domoticz

# read settings from config file:
. $(dirname "$0")/padd.config


# DATE
today=$(date +%Y%m%d)

# CORES
declare -i core_count=1
core_count=$(cat /sys/devices/system/cpu/kernel_max 2> /dev/null)+1

# COLORS
CSI="$(printf '\033')["
red_text="${CSI}91m"     # Red
green_text="${CSI}92m"   # Green
yellow_text="${CSI}93m"  # Yellow
blue_text="${CSI}94m"    # Blue
magenta_text="${CSI}95m" # Magenta
cyan_text="${CSI}96m"    # Cyan
reset_text="${CSI}0m"    # Reset to default

# STYLES
bold_text="${CSI}1m"
blinking_text="${CSI}5m"
dim_text="${CSI}2m"

# CHECK BOXES
check_box_good="[${green_text}✓${reset_text}]"       # Good
check_box_bad="[${bold_text}${red_text}✗${reset_text}]"          # Bad
check_box_question="[${bold_text}${yellow_text}?${reset_text}]"  # Question / ?
check_box_info="[${bold_text}${yellow_text}i${reset_text}]"      # Info / i

# PICO STATUSES
pico_status_ok="${check_box_good} Sys. OK"
pico_status_update="${check_box_info} Update"
pico_status_hot="${check_box_bad} Sys. Hot!"
pico_status_off="${check_box_bad} Offline"
pico_status_ftl_down="${check_box_info} FTL Down"
pico_status_dns_down="${check_box_bad} DNS Down"
pico_status_unknown="${check_box_question} Stat. Unk."

# MINI STATUS
mini_status_ok="${check_box_good} System OK"
mini_status_update="${check_box_info} Update avail."
mini_status_hot="${check_box_bad} System is hot!"
mini_status_off="${check_box_bad} Pi-hole off!"
mini_status_ftl_down="${check_box_info} FTL down!"
mini_status_dns_down="${check_box_bad} DNS off!"
mini_status_unknown="${check_box_question} Status unknown"

# REGULAR STATUS
full_status_ok="${check_box_good} System is healthy."
full_status_update="${check_box_info} Updates are available."
full_status_hot="${check_box_bad} System is hot!"
full_status_off="${check_box_bad} Pi-hole is offline"
full_status_ftl_down="${check_box_info} FTL is down!"
full_status_dns_down="${check_box_bad} DNS is off!"
full_status_unknown="${check_box_question} Status unknown!"

# MEGA STATUS
mega_status_ok="${check_box_good} Your system is healthy."
mega_status_update="${check_box_bad} Updates are available."
mega_status_hot="${check_box_bad} Your system is hot!"
mega_status_off="${check_box_bad} Pi-hole is offline."
mega_status_ftl_down="${check_box_info} FTLDNS service is not running."
mega_status_dns_down="${check_box_bad} Pi-hole's DNS server is off!"
mega_status_unknown="${check_box_question} Unable to determine Pi-hole status."

# TINY STATUS
tiny_status_ok="${check_box_good} System is healthy."
tiny_status_update="${check_box_info} Updates are available."
tiny_status_off="${check_box_bad} Pi-hole is offline"
tiny_status_ftl_down="${check_box_info} FTL is down!"
tiny_status_dns_down="${check_box_bad} DNS is off!"
tiny_status_unknown="${check_box_question} Status unknown!"

# Text only "logos"
padd_text="${green_text}${bold_text}PADD${reset_text}"
padd_text_retro="${bold_text}${red_text}P${yellow_text}A${green_text}D${blue_text}D${reset_text}${reset_text}"
mini_text_retro="${dim_text}${cyan_text}m${magenta_text}i${red_text}n${yellow_text}i${reset_text}"

# PADD logos - regular and retro
padd_logo_1="${bold_text}${green_text} __      __  __   ${reset_text}"
padd_logo_2="${bold_text}${green_text}|__) /\\ |  \\|  \\  ${reset_text}"
padd_logo_3="${bold_text}${green_text}|   /--\\|__/|__/  ${reset_text}"
padd_logo_retro_1="${bold_text} ${yellow_text}_${green_text}_      ${blue_text}_${magenta_text}_  ${yellow_text}_${green_text}_   ${reset_text}"
padd_logo_retro_2="${bold_text}${yellow_text}|${green_text}_${blue_text}_${cyan_text}) ${red_text}/${yellow_text}\\ ${blue_text}|  ${red_text}\\${yellow_text}|  ${cyan_text}\\  ${reset_text}"
padd_logo_retro_3="${bold_text}${green_text}|   ${red_text}/${yellow_text}-${green_text}-${blue_text}\\${cyan_text}|${magenta_text}_${red_text}_${yellow_text}/${green_text}|${blue_text}_${cyan_text}_${magenta_text}/  ${reset_text}"

############################################# FTL ##################################################

Authenticate() {
  echo "Checking FTL and password"
  sessionResponse="$(curl -skS -X POST "${API_URL}auth" --user-agent "PADD ${padd_version}${padd_build}" --data "{\"password\":\"${password}\"}" )"

  if [ -z "${sessionResponse}" ]; then
    echo "No response from FTL server. Please check connectivity and use the options to set the API URL"
    echo "Usage: $0 [--server <domain|IP>]"
    exit 1
  fi
	# obtain validity and session ID from session response
	validSession=$(echo "${sessionResponse}"| jq .session.valid 2>/dev/null)
  #validSession=false
	SID=$(echo "${sessionResponse}"| jq --raw-output .session.sid 2>/dev/null)
  echo "Vallid session ${validSession}"
  echo "SID ${SID}"
}

TestAPIAvailability() {

    local chaos_api_list availabilityResponse cmdResult digReturnCode

    # Query the API URLs from FTL using CHAOS TXT
    # The result is a space-separated enumeration of full URLs
    # e.g., "http://localhost:80/api" or "https://domain.com:443/api"
    if [ -z "${SERVER}" ] || [ "${SERVER}" = "localhost" ] || [ "${SERVER}" = "127.0.0.1" ]; then
        # --server was not set or set to local, assuming we're running locally
        cmdResult="$(dig +short chaos txt local.api.ftl @localhost 2>&1; echo $?)"
    else
        # --server was set, try to get response from there
        cmdResult="$(dig +short chaos txt domain.api.ftl @"${SERVER}" 2>&1; echo $?)"
    fi

    # Gets the return code of the dig command (last line)
    # We can't use${cmdResult##*$'\n'*} here as $'..' is not POSIX
    digReturnCode="$(echo "${cmdResult}" | tail -n 1)"

    if [ ! "${digReturnCode}" = "0" ]; then
        # If the query was not successful
        moveXOffset;  echo "API not available. Please check server address and connectivity"
        exit 1
    else
      # Dig returned 0 (success), so get the actual response (first line)
      chaos_api_list="$(echo "${cmdResult}" | head -n 1)"
    fi

    # Iterate over space-separated list of URLs
    while [ -n "${chaos_api_list}" ]; do
        # Get the first URL
        API_URL="${chaos_api_list%% *}"
        # Strip leading and trailing quotes
        API_URL="${API_URL%\"}"
        API_URL="${API_URL#\"}"

        # Test if the API is available at this URL
        availabilityResponse=$(curl -skS -o /dev/null -w "%{http_code}" "${API_URL}auth")

        # Test if http status code was 200 (OK) or 401 (authentication required)
        if [ ! "${availabilityResponse}" = 200 ] && [ ! "${availabilityResponse}" = 401 ]; then
            # API is not available at this port/protocol combination
            API_PORT=""
        else
            # API is available at this URL combination

            if [ "${availabilityResponse}" = 200 ]; then
                # API is available without authentication
                needAuth=false
            fi

            break
        fi

        # Remove the first URL from the list
        local last_api_list
        last_api_list="${chaos_api_list}"
        chaos_api_list="${chaos_api_list#* }"

        # If the list did not change, we are at the last element
        if [ "${last_api_list}" = "${chaos_api_list}" ]; then
            # Remove the last element
            chaos_api_list=""
        fi
    done

    # if API_PORT is empty, no working API port was found
    if [ -n "${API_PORT}" ]; then
        moveXOffset; echo "API not available at: ${API_URL}"
        moveXOffset; echo "Exiting."
        exit 1
    fi
}

LoginAPI() {
    echo "Run Login API"
    # Exit early if no authentication is required
    if [ "${needAuth}" = false ]; then
        moveXOffset; echo "No password required."
        return
    fi

    # Try to read the CLI password (if enabled and readable by the current user)
    if [ -r cli_pw ]; then
        password=$(cat cli_pw)
        echo "password found in file"
        # Try to authenticate using the CLI password
        Authenticate
    fi

    # If this did not work, ask the user for the password
    while [ "${validSession}" = false ] || [ -z "${validSession}" ] ; do
        moveXOffset; echo "Authentication failed."

        # no password was supplied as argument
        if [ -z "${password}" ]; then
            moveXOffset; echo "No password supplied. Please enter your password:"
        else
            moveXOffset; echo "Wrong password supplied, please enter the correct password:"
        fi

        # secretly read the password
        moveXOffset; secretRead; printf '\n'

        # Try to authenticate again
        Authenticate
    done

    # Loop exited, authentication was successful
    moveXOffset; echo "Authentication successful."

}

DeleteSession() {
    # if a valid Session exists (no password required or successful authenthication) and
    # SID is not null (successful authenthication only), delete the session
    if [ "${validSession}" = true ] && [ ! "${SID}" = null ]; then
        # Try to delete the session. Omit the output, but get the http status code
        deleteResponse=$(curl -skS -o /dev/null -w "%{http_code}" -X DELETE "${API_URL}auth"  -H "Accept: application/json" -H "sid: ${SID}")

        printf "\n\n"
        case "${deleteResponse}" in
            "204") moveXOffset; printf "%b" "Session successfully deleted.\n";;
            "401") moveXOffset; printf "%b" "Logout attempt without a valid session. Unauthorized!\n";;
         esac;
    else
      # no session to delete, just print a newline for nicer output
      echo
    fi

}

GetFTLData() {
  local response
  # get the data from querying the API as well as the http status code
	response=$(curl -skS -w "%{http_code}" -X GET "${API_URL}$1" -H "Accept: application/json" -H "sid: ${SID}" )

  # status are the last 3 characters
  status=$(printf %s "${response#"${response%???}"}")
  # data is everything from response without the last 3 characters
  data=$(printf %s "${response%???}")

  if [ "${status}" = 200 ]; then
    echo "${data}"
  elif [ "${status}" = 000 ]; then
    # connection lost
    echo "000"
  elif [ "${status}" = 401 ]; then
    # unauthorized
    echo "401"
  fi
}



############################################# GETTERS ##############################################

GetFTLData1() {
    local ftl_port LINE
    # ftl_port=$(cat /run/pihole-FTL.port 2> /dev/null)
    ftl_port=$(getFTLAPIPort)
    if [[ -n "$ftl_port" ]]; then
        # Open connection to FTL
        exec 3<>"/dev/tcp/127.0.0.1/$ftl_port"

        # Test if connection is open
        if { "true" >&3; } 2> /dev/null; then
            # Send command to FTL and ask to quit when finished
            echo -e ">$1 >quit" >&3

            # Read input until we received an empty string and the connection is
            # closed
            read -r -t 1 LINE <&3
            until [[ -z "${LINE}" ]] && [[ ! -t 3 ]]; do
                echo "$LINE" >&1
                read -r -t 1 LINE <&3
            done

            # Close connection
            exec 3>&-
            exec 3<&-
        fi
    else
        echo "0"
    fi

}

GetSummaryInformation() {
  summary=$(GetFTLData "stats/summary")
  
  cache_info=$(GetFTLData "info/metrics")
  
  ftl_info=$(GetFTLData "info/ftl")
  
  dns_blocking=$(GetFTLData "dns/blocking")
  
  clients=$(echo "${ftl_info}" | jq .ftl.clients.active 2>/dev/null)

  blocking_enabled=$(echo "${dns_blocking}" | jq .blocking 2>/dev/null)

  domains_being_blocked_raw=$(echo "${ftl_info}" | jq .ftl.database.gravity 2>/dev/null)
  domains_being_blocked=$(printf "%.f" "${domains_being_blocked_raw}")
  
  dns_queries_today_raw=$(echo "$summary" | jq .queries.total 2>/dev/null)
  dns_queries_today=$(printf "%.f" "${dns_queries_today_raw}")

  ads_blocked_today_raw=$(echo "$summary" | jq .queries.blocked 2>/dev/null)
  ads_blocked_today=$(printf "%.f" "${ads_blocked_today_raw}")

  ads_percentage_today_raw=$(echo "$summary" | jq .queries.percent_blocked 2>/dev/null)
  ads_percentage_today=$(printf "%.1f" "${ads_percentage_today_raw}")

  cache_size=$(echo "$cache_info" | jq .metrics.dns.cache.size 2>/dev/null)
  cache_evictions=$(echo "$cache_info" | jq .metrics.dns.cache.evicted 2>/dev/null)
  cache_inserts=$(echo "$cache_info"| jq .metrics.dns.cache.inserted 2>/dev/null)
  
  latest_blocked_raw=$(GetFTLData "stats/recent_blocked?show=1" | jq --raw-output .blocked[0] 2>/dev/null)
  
  top_blocked_raw=$(GetFTLData "stats/top_domains?blocked=true" | jq --raw-output .domains[0].domain 2>/dev/null)
  
  top_domain_raw=$(GetFTLData "stats/top_domains" | jq --raw-output .domains[0].domain 2>/dev/null)
  
  top_client_raw=$(GetFTLData "stats/top_clients" | jq --raw-output .clients[0].name 2>/dev/null)
  if [ -z "${top_client_raw}" ]; then
    # if no hostname was supplied, use IP
    top_client_raw=$(GetFTLData "stats/top_clients" | jq --raw-output .clients[0].ip 2>/dev/null)
  fi
  
  ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 30 "color")

  latest_blocked=$(truncateString "$latest_blocked_raw" 68)
  top_blocked=$(truncateString "$top_blocked_raw" 68)
  top_domain=$(truncateString "$top_domain_raw" 68)
  top_client=$(truncateString "$top_client_raw" 68)
  
  LC_ALL=da_DK.UTF-8
  LC_NUMERIC=da_DK.UTF-8
  domains_being_blocked1=$(printf "%'d" $domains_being_blocked_raw)
  dns_queries_today1=$(printf "%'d" "${dns_queries_today_raw}")
  ads_blocked_today1=$(printf "%'d" "${ads_blocked_today_raw}")
  LC_ALL=C
  LC_NUMERIC=C
  
}

GetSummaryInformation1() {
  local summary
  local cache_info
  summary=$(GetFTLData "stats")
  cache_info=$(GetFTLData "cacheinfo")

  clients=$(grep "unique_clients" <<< "${summary}" | grep -Eo "[0-9]+$")

  domains_being_blocked_raw=$(grep "domains_being_blocked" <<< "${summary}" | grep -Eo "[0-9]+$")
  domains_being_blocked=$(printf "%'.f" "${domains_being_blocked_raw}")

  dns_queries_today_raw=$(grep "dns_queries_today" <<< "$summary" | grep -Eo "[0-9]+$")
  dns_queries_today=$(printf "%'.f" "${dns_queries_today_raw}")

  ads_blocked_today_raw=$(grep "ads_blocked_today" <<< "$summary" | grep -Eo "[0-9]+$")
  ads_blocked_today=$(printf "%'.f" "${ads_blocked_today_raw}")

  ads_percentage_today_raw=$(grep "ads_percentage_today" <<< "$summary" | grep -Eo "[0-9.]+$")
  ads_percentage_today=$(printf "%'.1f" "${ads_percentage_today_raw}")

  cache_size=$(grep "cache-size" <<< "$cache_info" | grep -Eo "[0-9.]+$")
  cache_deletes=$(grep "cache-live-freed" <<< "$cache_info" | grep -Eo "[0-9.]+$")
  cache_inserts=$(grep "cache-inserted" <<< "$cache_info" | grep -Eo "[0-9.]+$")

  latest_blocked=$(GetFTLData recentBlocked)

  top_blocked=$(GetFTLData "top-ads (1)" | awk '{print $3}')

  top_domain=$(GetFTLData "top-domains (1)" | awk '{print $3}')

  read -r -a top_client_raw <<< "$(GetFTLData "top-clients (1)")"
  if [[ "${top_client_raw[3]}" ]]; then
    top_client="${top_client_raw[3]}"
  else
    top_client="${top_client_raw[2]}"
  fi

  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 10 "color")
  elif [ "$1" = "mini" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 20 "color")

    if [ ${#latest_blocked} -gt 30 ]; then
      latest_blocked=$(echo "$latest_blocked" | cut -c1-27)"..."
    fi

    if [ ${#top_blocked} -gt 30 ]; then
      top_blocked=$(echo "$top_blocked" | cut -c1-27)"..."
    fi
  elif [ "$1" = "tiny" ]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 30 "color")

    if [ ${#latest_blocked} -gt 38 ]; then
      latest_blocked=$(echo "$latest_blocked" | cut -c1-38)"..."
    fi

    if [ ${#top_blocked} -gt 38 ]; then
      top_blocked=$(echo "$top_blocked" | cut -c1-38)"..."
    fi     

    if [ ${#top_domain} -gt 38 ]; then
      top_domain=$(echo "$top_domain" | cut -c1-38)"..."
    fi

    if [ ${#top_client} -gt 38 ]; then
      top_client=$(echo "$top_client" | cut -c1-38)"..."
    fi
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 20 "color")
  else
    #ads_blocked_bar=$(BarGenerator "$ads_percentage_today" 20 "color")
    ads_blocked_bar=$(echo "ADDS BAR")
    
  fi
}

GetSystemInformation() {
  # System uptime
  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    system_uptime=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/){if ($9=="min") {d=$6;m=$8} else {d=$6;h=$8;m=$9}} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours"}')
  else
    system_uptime=$(uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/){if ($9=="min") {d=$6;m=$8} else {d=$6;h=$8;m=$9}} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
  fi

  # CPU temperature
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    cpu=$(</sys/class/thermal/thermal_zone0/temp)
  elif [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
    cpu=$(</sys/class/hwmon/hwmon0/temp1_input)
  else
    cpu=0
  fi

  # Convert CPU temperature to correct unit
  if [ "${TEMPERATUREUNIT}" == "F" ]; then
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 * 9 / 5000 + 32}')")°F"
  elif [ "${TEMPERATUREUNIT}" == "K" ]; then
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 / 1000 + 273.15}')")°K"
  # Addresses Issue 1: https://github.com/jpmck/PAD/issues/1
  else
    temperature="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 / 1000}')")°C"
    temperature1="$(printf %.1f "$(echo "${cpu}" | awk '{print $1 / 1000}')")"
  fi
  echo "$temperature1" > /home/pi/temperature.log

  if [[ "$dzhost" != "" ]]; then
      wget -q --delete-after "http://$dzhost/json.htm?type=command&param=udevice&idx=$idxtmp&svalue=$temperature1" #>>speedtest.log # >/dev/null 2>&1
  fi

  # CPU load, heatmap
  read -r -a cpu_load < /proc/loadavg
  cpu_load_1_heatmap=$(HeatmapGenerator "${cpu_load[0]}" "${core_count}")
  cpu_load_5_heatmap=$(HeatmapGenerator "${cpu_load[1]}" "${core_count}")
  cpu_load_15_heatmap=$(HeatmapGenerator "${cpu_load[2]}" "${core_count}")
  # OLD: cpu_percent=$(printf %.1f "$(echo "${cpu_load[0]} ${core_count}" | awk '{print ($1 / $2) * 100}')")
  
  # Get the total CPU statistics, discarding the 'cpu ' prefix.
  
  CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
  IDLE=${CPU[3]} # Just the idle CPU time.

  # Calculate the total CPU time.
  TOTAL=0
  for VALUE in "${CPU[@]:0:8}"; do
    TOTAL=$((TOTAL+VALUE))
  done

  # Calculate the CPU usage since we last checked.
  DIFF_IDLE=$((IDLE-PREV_IDLE))
  DIFF_TOTAL=$((TOTAL-PREV_TOTAL))
  # DIFF_USAGE=$(((1000*(DIFF_TOTAL-DIFF_IDLE)/DIFF_TOTAL+5)/10))
  DIFF_USAGE=$(((1000*(DIFF_TOTAL-DIFF_IDLE)/DIFF_TOTAL+5)))

  DIFF_USAGE=$(echo "scale=1; $DIFF_USAGE / 10" | bc)
  
  cpu_percent=$DIFF_USAGE
  
  cpu_int=${cpu_percent%.*}

  if [ $cpu_int -gt 100 ]; then 
    cpu_percent="100"
  fi

  echo "$cpu_percent" > /home/pi/cpu.log
  
  if [[ "$dzhost" != "" ]]; then
    wget -q --delete-after "http://$dzhost/json.htm?type=command&param=udevice&idx=$idxcpu&svalue=$cpu_percent" #>>speedtest.log # >/dev/null 2>&1
  fi
  
  # Remember the total and idle CPU times for the next check.
  PREV_TOTAL="$TOTAL"
  PREV_IDLE="$IDLE"
  
  # CPU temperature heatmap
  # If we're getting close to 85°C... (https://www.raspberrypi.org/blog/introducing-turbo-mode-up-to-50-more-performance-for-free/)
  if [ ${cpu} -gt 80000 ]; then
    temp_heatmap=${blinking_text}${red_text}
    pico_status="${pico_status_hot}"
    mini_status_="${mini_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
    full_status_="${full_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
    mega_status="${mega_status_hot} ${blinking_text}${red_text}${temperature}${reset_text}"
  elif [ ${cpu} -gt 70000 ]; then
    temp_heatmap=${magenta_text}
  elif [ ${cpu} -gt 60000 ]; then
    temp_heatmap=${yellow_text}
  else
    temp_heatmap=${cyan_text}
  fi

  # Memory use, heatmap and bar
  memory_percent=$(awk '/MemTotal:/{total=$2} /MemFree:/{free=$2} /Buffers:/{buffers=$2} /^Cached:/{cached=$2} END {printf "%.1f", (total-free-buffers-cached)*100/total}' '/proc/meminfo')
  memory_heatmap=$(HeatmapGenerator "${memory_percent}")

  #  Bar generations
  if [ "$1" = "mini" ]; then
    cpu_bar=$(BarGenerator "${cpu_percent}" 20)
    memory_bar=$(BarGenerator "${memory_percent}" 20)
  elif [ "$1" = "tiny" ]; then
    cpu_bar=$(BarGenerator "${cpu_percent}" 7)
    memory_bar=$(BarGenerator "${memory_percent}" 7)
  else
    cpu_bar=$(BarGenerator "${cpu_percent}" 10)
    memory_bar=$(BarGenerator "${memory_percent}" 10)
  fi
}

GetNetworkInformation() {
  # Get pi IPv4 address
  readarray -t pi_ip4_addrs <<< "$(ip addr | grep 'inet ' | grep -v '127.0.0.1/8' | awk '{print $2}' | cut -f1 -d'/')"
  if [ ${#pi_ip4_addrs[@]} -eq 0 ]; then
    # No IPv4 address available
    pi_ip4_addr="N/A"
  elif [ ${#pi_ip4_addrs[@]} -eq 1 ]; then
    # One IPv4 address available
    pi_ip4_addr="${pi_ip4_addrs[0]}"
  else
    # More than one IPv4 address available
    pi_ip4_addr="${pi_ip4_addrs[0]}+"
  fi

  # Get pi IPv6 address
  readarray -t pi_ip6_addrs <<< "$(ip addr | grep 'inet6 ' | grep -v '::1/128' | awk '{print $2}' | cut -f1 -d'/')"
  if [ ${#pi_ip6_addrs[@]} -eq 0 ]; then
    # No IPv6 address available
    pi_ip6_addr="N/A"
  elif [ ${#pi_ip6_addrs[@]} -eq 1 ]; then
    # One IPv6 address available
    pi_ip6_addr="${pi_ip6_addrs[0]}"
  else
    # More than one IPv6 address available
    pi_ip6_addr="${pi_ip6_addrs[0]}+"
  fi

  # Get hostname and gateway
  pi_hostname=$(hostname)
  pi_gateway=$(ip r | grep 'default' | awk '{print $3}')

  full_hostname=${pi_hostname}
  # does the Pi-hole have a domain set?
  if [ -n "${PIHOLE_DOMAIN+x}" ]; then
    # is Pi-hole acting as DHCP server?
    if [[ "${DHCP_ACTIVE}" == "true" ]]; then
      count=${pi_hostname}"."${PIHOLE_DOMAIN}
      count=${#count}
      if [ "${count}" -lt "18" ]; then
        full_hostname=${pi_hostname}"."${PIHOLE_DOMAIN}
      fi
    fi
  fi

  # Get the DNS count (from pihole -c)
  dns_count="0"
  [[ -n "${PIHOLE_DNS_1}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_2}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_3}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_4}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_5}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_6}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_7}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_8}" ]] && dns_count=$((dns_count+1))
  [[ -n "${PIHOLE_DNS_9}" ]] && dns_count=$((dns_count+1))

  # if there's only one DNS server
  if [[ ${dns_count} -eq 1 ]]; then
    if [[ "${PIHOLE_DNS_1}" == "127.0.0.1#5053" ]]; then
      dns_information="1 server (Cloudflared)"
    elif [[ "${PIHOLE_DNS_1}" == "${pi_gateway}#53" ]]; then
      dns_information="1 server (gateway)"
    else
      dns_information="1 server"
    fi
  elif [[ ${dns_count} -gt 8 ]]; then
    dns_information="8+ servers"
  else
    dns_information="${dns_count} servers"
  fi

  # Is Pi-Hole acting as the DHCP server?
  if [[ "${DHCP_ACTIVE}" == "true" ]]; then
    dhcp_status="Enabled"
    dhcp_leasecount=$(wc -l /etc/pihole/dhcp.leases  | awk '{print $1}')
    dhcp_percent=$(echo $dhcp_leasecount | awk '{printf "%5.1f", (($1+1)/140)*100}')
    dhcp_bar=$(BarGenerator "${dhcp_percent}" 20)
    dhcp_heatmap=$(HeatmapGenerator "${dhcp_percent}")
    dhcp_info=" Range:    ${DHCP_START} - ${DHCP_END} Leases: ${dhcp_leasecount}"
    dhcp_heatmap=${green_text}
    dhcp_check_box=${check_box_good}

    # Is DHCP handling IPv6?
    # DHCP_IPv6 is set in setupVars.conf
    # shellcheck disable=SC2154
    if [[ "${DHCP_IPv6}" == "true" ]]; then
      dhcp_ipv6_status="Enabled"
      dhcp_ipv6_heatmap=${green_text}
      dhcp_ipv6_check_box=${check_box_good}
    else
      dhcp_ipv6_status="Disabled"
      dhcp_ipv6_heatmap=${red_text}
      dhcp_ipv6_check_box=${check_box_bad}
    fi
  else
    dhcp_status="Disabled"
    dhcp_heatmap=${red_text}
    dhcp_check_box=${check_box_bad}

    # if the DHCP Router variable isn't set
    # Issue 3: https://github.com/jpmck/PADD/issues/3
    if [ -z ${DHCP_ROUTER+x} ]; then
      DHCP_ROUTER=$(/sbin/ip route | awk '/default/ { printf "%s\t", $3 }')
    fi

    dhcp_info=" Router:   ${DHCP_ROUTER}"
    dhcp_heatmap=${red_text}
    dhcp_check_box=${check_box_bad}

    dhcp_ipv6_status="N/A"
    dhcp_ipv6_heatmap=${yellow_text}
    dhcp_ipv6_check_box=${check_box_question}
  fi

  # DNSSEC
  if [[ "${DNSSEC}" == "true" ]]; then
    dnssec_status="Enabled"
    dnssec_heatmap=${green_text}
    dnssec_check_box=${check_box_good}
  else
    dnssec_status="Disabled"
    dnssec_heatmap=${red_text}
    dnssec_check_box=${check_box_bad}
  fi

  # Conditional forwarding
  if [[ "${CONDITIONAL_FORWARDING}" == "true" ]] || [[ "${REV_SERVER}" == "true" ]]; then
    conditional_forwarding_status="Enabled"
    conditional_forwarding_heatmap=${green_text}
    conditional_forwarding_check_box=${check_box_good}
  else
    conditional_forwarding_status="Disabled"
    conditional_forwarding_heatmap=${red_text}
    conditional_forwarding_check_box=${check_box_bad}
  fi
}

GetPiholeInformation() {
  # Get Pi-hole status
  pihole_web_status=$(pihole status web)

  if [[ ${pihole_web_status} -ge 1 ]]; then
    pihole_status="Active"
    pihole_heatmap=${green_text}
    pihole_check_box=${check_box_good}
  elif [[ ${pihole_web_status} == 0 ]]; then
    pihole_status="Offline"
    pihole_heatmap=${red_text}
    pihole_check_box=${check_box_bad}
    pico_status=${pico_status_off}
    mini_status_=${mini_status_off}
    tiny_status_=${tiny_status_off}   
    full_status_=${full_status_off}
    mega_status=${mega_status_off}
  elif [[ ${pihole_web_status} == -1 ]]; then
    pihole_status="DNS Offline"
    pihole_heatmap=${red_text}
    pihole_check_box=${check_box_bad}
    pico_status=${pico_status_dns_down}
    mini_status_=${mini_status_dns_down}
    tiny_status_=${tiny_status_dns_down} 
    full_status_=${full_status_dns_down}
    mega_status=${mega_status_dns_down}
  else
    pihole_status="Unknown"
    pihole_heatmap=${yellow_text}
    pihole_check_box=${check_box_question}
    pico_status=${pico_status_unknown}
    mini_status_=${mini_status_unknown}
    tiny_status_=${tiny_status_unknown}  
    full_status_=${full_status_unknown}
    mega_status=${mega_status_unknown}
  fi

  # Get FTL status
  ftlPID=$(pidof pihole-FTL)

  if [ -z ${ftlPID+x} ]; then
    ftl_status="Not running"
    ftl_heatmap=${yellow_text}
    ftl_check_box=${check_box_info}
    pico_status=${pico_status_ftl_down}
    mini_status_=${mini_status_ftl_down}
    tiny_status_=${tiny_status_ftl_down}    
    full_status_=${full_status_ftl_down}
    mega_status=${mega_status_ftl_down}
  else
    ftl_status="Running"
    ftl_heatmap=${green_text}
    ftl_check_box=${check_box_good}
    ftl_cpu="$(ps -p "${ftlPID}" -o %cpu | tail -n1 | tr -d '[:space:]')"
    ftl_mem_percentage="$(ps -p "${ftlPID}" -o %mem | tail -n1 | tr -d '[:space:]')"
  fi
}

GetVersionInformation() {
  # Check if version status has been saved
  if [ -e "piHoleVersion" ]; then # the file exists...
    # the file exits, use it
    # shellcheck disable=SC1091
    source piHoleVersion

    # Today is...
    today=$(date +%Y%m%d)

    # was the last check today?
    # last_check is read from ./piHoleVersion
    # shellcheck disable=SC2154
    if [ "${today}" != "${last_check}" ]; then # no, it wasn't today
      # Remove the Pi-hole version file...
      rm -f piHoleVersion
    fi

  else # the file doesn't exist, create it...
    # Gather core version information...
    read -r -a core_versions <<< "$(pihole -v -p)"
    core_version=$(echo "${core_versions[3]}" | tr -d '\r\n[:alpha:]')
    core_version_latest=${core_versions[5]//)}
    out_of_date_flag=""
    if [[ "${core_version_latest}" == "ERROR" ]]; then
      core_version_latest=${core_version}
      core_version_heatmap=${yellow_text}
    else
      core_version_latest=$(echo "${core_version_latest}" | tr -d '\r\n[:alpha:]')
      # is core up-to-date?
      if [[ "${core_version}" != "${core_version_latest}" ]]; then
        out_of_date_flag="true"
        core_version_heatmap=${red_text}
      else
        core_version_heatmap=${green_text}
      fi
    fi

    # Gather web version information...
     if [[ "$INSTALL_WEB_INTERFACE" = true ]]; then
      read -r -a web_versions <<< "$(pihole -v -a)"
      web_version=$(echo "${web_versions[3]}" | tr -d '\r\n[:alpha:]')
      web_version_latest=${web_versions[5]//)}
      if [[ "${web_version_latest}" == "ERROR" ]]; then
          web_version_latest=${web_version}
          web_version_heatmap=${yellow_text}
      else
        web_version_latest=$(echo "${web_version_latest}" | tr -d '\r\n[:alpha:]')
        # is web up-to-date?
        if [[ "${web_version}" != "${web_version_latest}" ]]; then
          out_of_date_flag="true"
          web_version_heatmap=${red_text}
        else
          web_version_heatmap=${green_text}
        fi
      fi
     else
      # Web interface not installed
      web_version_heatmap=${red_text}
      web_version="$(printf '\x08')"  # Hex 0x08 is for backspace, to delete the leading 'v'
      web_version="${web_version}N/A" # N/A = Not Available
    fi

    # Gather FTL version information...
    read -r -a ftl_versions <<< "$(pihole -v -f)"
    ftl_version=$(echo "${ftl_versions[3]}" | tr -d '\r\n[:alpha:]')
    ftl_version_latest=${ftl_versions[5]//)}
    if [[ "${ftl_version_latest}" == "ERROR" ]]; then
      ftl_version_latest=${ftl_version}
      ftl_version_heatmap=${yellow_text}
    else
      ftl_version_latest=$(echo "${ftl_version_latest}" | tr -d '\r\n[:alpha:]')
      # is ftl up-to-date?
      if [[ "${ftl_version}" != "${ftl_version_latest}" ]]; then
        out_of_date_flag="true"
        ftl_version_heatmap=${red_text}
      else
        ftl_version_heatmap=${green_text}
      fi
    fi

    # PADD version information...
    # Fix 3.2.2padd_version_latest=$(curl -sI https://github.com/jpmck/PADD/releases/latest | awk -F / 'tolower($0) ~ /^location:/ {print $NF; exit}' | tr -d '\r\n[:alpha:]')
    
    # padd_version_latest=$(json_extract tag_name "$(curl -s 'https://api.github.com/repos/pi-hole/PADD/releases/latest' 2> /dev/null)")

    # is PADD up-to-date?
    if [[ "${padd_version_latest}" == "" ]]; then
      padd_version_heatmap=${yellow_text}
    else   
      if [[ "${padd_version}" != "${padd_version_latest}" ]]; then
        padd_out_of_date_flag="true"
        padd_version_heatmap=${red_text}
      else
        padd_version_heatmap=${green_text}
      fi
    fi    

    # was any portion of Pi-hole out-of-date?
    # yes, pi-hole is out of date
    if [[ "${out_of_date_flag}" == "true" ]]; then
      version_status="Pi-hole is out-of-date!"
      version_heatmap=${red_text}
      version_check_box=${check_box_bad}
      pico_status=${pico_status_update}
      mini_status_=${mini_status_update}
      tiny_status_=${tiny_status_update} 
      full_status_=${full_status_update}
      mega_status=${mega_status_update}
    else
      # but is PADD out-of-date?
      if [[ "${padd_out_of_date_flag}" == "true" ]]; then
        version_status="PADD is out-of-date!"
        version_heatmap=${red_text}
        version_check_box=${check_box_bad}
        pico_status=${pico_status_update}
        mini_status_=${mini_status_update}
        tiny_status_=${tiny_status_update}        
        full_status_=${full_status_update}
        mega_status=${mega_status_update}
      # else, everything is good!
      else
        version_status="Pi-hole is up-to-date!"
        version_heatmap=${green_text}
        version_check_box=${check_box_good}
        pico_status=${pico_status_ok}
        mini_status_=${mini_status_ok}
        tiny_status_=${tiny_status_ok}         
        full_status_=${full_status_ok}
        mega_status=${mega_status_ok}
      fi
    fi

    # write it all to the file
    echo "last_check=${today}" > ./piHoleVersion
    {
      echo "core_version=$core_version"
      echo "core_version_latest=$core_version_latest"     
      echo "core_version_heatmap=$core_version_heatmap"

      echo "web_version=$web_version"
      echo "web_version_latest=$web_version_latest"         
      echo "web_version_heatmap=$web_version_heatmap"

      echo "ftl_version=$ftl_version"
      echo "ftl_version_latest=$ftl_version_latest"       
      echo "ftl_version_heatmap=$ftl_version_heatmap"

      echo "padd_version=$padd_version"
      echo "padd_version_latest=$padd_version_latest"       
      echo "padd_version_heatmap=$padd_version_heatmap"

      echo "version_status=\"$version_status\""
      echo "version_heatmap=$version_heatmap"
      echo "version_check_box=\"$version_check_box\""

      echo "pico_status=\"$pico_status\""
      echo "mini_status_=\"$mini_status_\""
      echo "tiny_status_=\"$tiny_status_\""        
      echo "full_status_=\"$full_status_\""
      echo "mega_status=\"$mega_status\""
    } >> ./piHoleVersion

    # there's a file now
  fi
}

############################################# PRINTERS #############################################

# terminfo clr_eol (clears to end of line to erase artifacts after resizing smaller)
ceol=$(tput el)

# wrapper - echo with a clear eol afterwards to wipe any artifacts remaining from last print
CleanEcho() {
  echo -e "${ceol}$1"
}

# wrapper - printf
CleanPrintf() {
# tput el
# disabling shellcheck here because we pass formatting instructions within `"${@}"`
# shellcheck disable=SC2059
  printf "$@"
}

 PrintLogo() {
  clock=$(date +%H:%M:%S)
  # osupdate=$(sudo apt-get -s upgrade | grep opgraderes | awk '{print $1}')
  osupdate=$(more /home/pi/UpdateNeeded.txt)
  
  # Screen size checks
  if [ "$1" = "pico" ]; then
    CleanEcho "p${padd_text} ${pico_status}"
  elif [ "$1" = "nano" ]; then
    CleanEcho "n${padd_text} ${mini_status_}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "µ${padd_text}     ${mini_status_}"
    CleanEcho ""
  elif [ "$1" = "mini" ]; then
    CleanEcho "${padd_text}${dim_text}mini${reset_text}  ${mini_status_}"
    CleanEcho ""
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${padd_text}${dim_text}tiny${reset_text}   Pi-hole® ${core_version_heatmap}v${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}"
    CleanPrintf "           PADD ${padd_version_heatmap}${padd_version}${reset_text} ${tiny_status_}${reset_text}\e[0K\\n"
  elif [ "$1" = "slim" ]; then
    CleanEcho "${padd_text}${dim_text}slim${reset_text}   ${full_status_}"
    CleanEcho ""
  # For the next two, use printf to make sure spaces aren't collapsed
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    CleanPrintf "${padd_logo_1}\e[0K\\n"
    CleanPrintf "${padd_logo_2}Pi-hole® ${core_version_heatmap}v${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}\e[0K\\n"
    CleanPrintf "${padd_logo_3}PADD ${padd_version_heatmap}${padd_version}${reset_text}${full_status_}${reset_text}\e[0K\\n"
    CleanEcho ""
  # normal or not defined
  else
    CleanPrintf "${padd_logo_retro_1}\e[0K\\n"
    CleanPrintf "${padd_logo_retro_2}   Pi-hole® ${core_version_heatmap}${core_version}${reset_text}, Web ${web_version_heatmap}v${web_version}${reset_text}, FTL ${ftl_version_heatmap}v${ftl_version}${reset_text}, PADD ${padd_version_heatmap}${padd_version}$padd_build${reset_text}\e[0K\\n"
    CleanPrintf "${padd_logo_retro_3}   ${pihole_check_box} Core  ${ftl_check_box} FTL   ${mega_status}${reset_text}\e[0K\\n"
    # CleanEcho ""
     if [ "$osupdate" == "Searching" ]; then
        CleanPrintf "(${red_text}U${reset_text}) ${bold_text}${yellow_text}  $clock ${reset_text}      ${bold_text}${yellow_text}$osupdate for OS Updates ${reset_text}\e[0K\\n"
     elif [ "$osupdate" == "Patching" ]; then
        CleanPrintf "(${red_text}U${reset_text}) ${bold_text}${yellow_text}  $clock ${reset_text}      ${bold_text}${green_text}$osupdate with OS Updates ${reset_text}\e[0K\\n"
     elif [ "$osupdate" != "0" ]; then
        CleanPrintf "(${red_text}U${reset_text}) ${bold_text}${yellow_text}  $clock ${reset_text}      [${bold_text}${red_text}$osupdate${reset_text}]  ${bold_text}${red_text}OS Updates pending ${reset_text}\e[0K\\n"
    else  
        CleanPrintf "(${red_text}U${reset_text}) ${bold_text}${yellow_text}  $clock ${reset_text}      ${check_box_good} OS is uptodate ${reset_text}\e[0K\\n"
    fi
  fi
}

PrintNetworkInformation() {
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}NETWORK ============${reset_text}"
    CleanEcho " Hst: ${pi_hostname}"
    CleanEcho " IP:  ${pi_ip4_addr}"
    CleanEcho " DHCP ${dhcp_check_box} IPv6 ${dhcp_ipv6_check_box}"
  elif [ "$1" = "nano" ]; then
    CleanEcho "${bold_text}NETWORK ================${reset_text}"
    CleanEcho " Host: ${pi_hostname}"
    CleanEcho " IP:  ${pi_ip4_addr}"
    CleanEcho " DHCP: ${dhcp_check_box}    IPv6: ${dhcp_ipv6_check_box}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}NETWORK ======================${reset_text}"
    CleanEcho " Host:    ${full_hostname}"
    CleanEcho " IP:      ${pi_ip4_addr}"
    CleanEcho " DHCP:    ${dhcp_check_box}     IPv6:  ${dhcp_ipv6_check_box}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}NETWORK ================================${reset_text}"
    CleanPrintf " %-9s%-19s\e[0K\\n" "Host:" "${full_hostname}"
    CleanPrintf " %-9s%-19s\e[0K\\n" "IP:"   "${pi_ip4_addr}"
    CleanPrintf " %-9s%-10s\e[0K\\n" "DNS:" "${dns_information}"

    if [[ "${DHCP_ACTIVE}" == "true" ]]; then
      CleanPrintf " %-9s${dhcp_heatmap}%-10s${reset_text} %-9s${dhcp_ipv6_heatmap}%-10s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
    fi
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}NETWORK ============================================${reset_text}"
    CleanPrintf " %-10s%-16s %-8s%-16s\e[0K\\n" "Hostname:" "${full_hostname}" "IP:  " "${pi_ip4_addr}"
    CleanPrintf " %-6s%-39s\e[0K\\n" "IPv6:" "${pi_ip6_addr}"
    CleanPrintf " %-10s%-16s %-8s%-16s\e[0K\\n" "DNS:" "${dns_information}" "DNSSEC:" "${dnssec_heatmap}${dnssec_status}${reset_text}"

    if [[ "${DHCP_ACTIVE}" == "true" ]]; then
      CleanPrintf " %-10s${dhcp_heatmap}%-16s${reset_text} %-8s${dhcp_ipv6_heatmap}%-10s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
      CleanPrintf "%s\e[0K\\n" "${dhcp_info}"
    fi
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    CleanEcho "${bold_text}NETWORK ===================================================${reset_text}"
    CleanPrintf " %-10s%-19s %-10s%-19s\e[0K\\n" "Hostname:" "${full_hostname}" "IP:" "${pi_ip4_addr}"
    CleanPrintf " %-6s%-19s\e[0K\\n" "IPv6:" "${pi_ip6_addr}"
    CleanPrintf " %-10s%-19s %-10s%-19s\e[0K\\n" "DNS:" "${dns_information}" "DNSSEC:" "${dnssec_heatmap}${dnssec_status}${reset_text}"

    if [[ "${DHCP_ACTIVE}" == "true" ]]; then
      CleanPrintf " %-10s${dhcp_heatmap}%-19s${reset_text} %-10s${dhcp_ipv6_heatmap}%-19s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6:" ${dhcp_ipv6_status}
      CleanPrintf "%s\e[0K\\n" "${dhcp_info}"
    fi
  else
    CleanEcho "${bold_text}NETWORK =======================================================================${reset_text}"
    CleanPrintf " %-10s%-19s\e[0K\\n" "Hostname:" "${full_hostname}"
    CleanPrintf " %-6s%-19s %-10s%-29s\e[0K\\n" "IPv4:" "${pi_ip4_addr}" "IPv6:" "${pi_ip6_addr}"
#   CleanEcho "DNS ==========================================================================="
#   CleanPrintf " %-10s%-39s\e[0K\\n" "Servers:" "${dns_information}"
#   CleanPrintf " %-10s${dnssec_heatmap}%-19s${reset_text} %-20s${conditional_forwarding_heatmap}%-9s${reset_text}\e[0K\\n" "DNSSEC:" "${dnssec_status}" "Conditional Fwding:" "${conditional_forwarding_status}"

    CleanEcho "DHCP =========================================================================="
    CleanPrintf " %-10s${dhcp_heatmap}%-19s${reset_text} %-10s${dhcp_ipv6_heatmap}%-9s${reset_text}\e[0K\\n" "DHCP:" "${dhcp_status}" "IPv6 Spt:" "${dhcp_ipv6_status}"
    CleanPrintf "%s\e[0K\\n" "${dhcp_info} [${dhcp_heatmap}${dhcp_bar}]${dhcp_percent}%"
    
    CleanEcho "Monitors ======================================================================"
    CleanPrintf " %-10s%-4s %-15s %-10s%-4s %-15s\e[0K\\n" "${alarm1t}" "${alarm1c}" "${alarm1r}" "${alarm2t}" "${alarm2c}" "${alarm2r}"
    CleanPrintf " %-10s%-4s %-15s %-10s%-4s %-15s\e[0K\\n" "${alarm3t}" "${alarm3c}" "${alarm3r}" "${alarm4t}" "${alarm4c}" "${alarm4r}"
  fi
}

PrintPiholeInformation() {
  # size checks
  if [ "$1" = "pico" ]; then
    :
  elif [ "$1" = "nano" ]; then
    CleanEcho "${bold_text}PI-HOLE ================${reset_text}"
    CleanEcho " Up:  ${pihole_check_box}      FTL: ${ftl_check_box}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}PI-HOLE ======================${reset_text}"
    CleanEcho " Status:  ${pihole_check_box}      FTL:  ${ftl_check_box}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}PI-HOLE ================================${reset_text}"
    CleanPrintf " %-9s${pihole_heatmap}%-10s${reset_text} %-9s${ftl_heatmap}%-10s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}PI-HOLE ============================================${reset_text}"
    CleanPrintf " %-10s${pihole_heatmap}%-16s${reset_text} %-8s${ftl_heatmap}%-10s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    CleanEcho "${bold_text}PI-HOLE ===================================================${reset_text}"
    CleanPrintf " %-10s${pihole_heatmap}%-19s${reset_text} %-10s${ftl_heatmap}%-19s${reset_text}\e[0K\\n" "Status:" "${pihole_status}" "FTL:" "${ftl_status}"
  else
    return
  fi
}

PrintPiholeStats() {
  # are we on a reduced screen size?
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}PI-HOLE ============${reset_text}"
    CleanEcho " [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "nano" ]; then
    CleanEcho " Blk: [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " Blk: ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}STATS ========================${reset_text}"
    CleanEcho " Blckng:  ${domains_being_blocked} domains"
    CleanEcho " Piholed: [${ads_blocked_bar}] ${ads_percentage_today}%"
    CleanEcho " Piholed: ${ads_blocked_today} / ${dns_queries_today}"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}STATS ==================================${reset_text}"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Blckng:" "${domains_being_blocked} domains"
    CleanPrintf " %-9s[%-20s] %-5s\e[0K\\n" "Piholed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Piholed:" "${ads_blocked_today} out of ${dns_queries_today}"
    CleanPrintf " %-9s%-29s\e[0K\\n" "Latest:" "${latest_blocked}"
    if [[ "${DHCP_ACTIVE}" != "true" ]]; then
      CleanPrintf " %-9s%-29s\\n" "Top Ad:" "${top_blocked}"
    fi
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}STATS ==============================================${reset_text}"
    CleanPrintf " %-10s%-29s\e[0K\\n" "Blocking:" "${domains_being_blocked} domains"
    CleanPrintf " %-10s[%-30s] %-5s\e[0K\\n" "Pi-holed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Pi-holed:" "${ads_blocked_today} out of ${dns_queries_today}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    if [[ "${DHCP_ACTIVE}" != "true" ]]; then
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    fi
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    CleanEcho "${bold_text}STATS =====================================================${reset_text}"
    CleanPrintf " %-10s%-49s\e[0K\\n" "Blocking:" "${domains_being_blocked} domains"
    CleanPrintf " %-10s[%-40s] %-5s\e[0K\\n" "Pi-holed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-49s\e[0K\\n" "Pi-holed:" "${ads_blocked_today} out of ${dns_queries_today} queries"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    if [[ "${DHCP_ACTIVE}" != "true" ]]; then
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
      CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    fi
  else
    CleanEcho "${bold_text}STATS =========================================================================${reset_text}"
    CleanPrintf " %-10s%-19s %-10s[%-40s] %-5s\e[0K\\n" "Blocking:" "${domains_being_blocked1} domains" "Piholed:" "${ads_blocked_bar}" "${ads_percentage_today}%"
    CleanPrintf " %-10s%-30s%-29s\e[0K\\n" "Clients:" "${clients}" " ${ads_blocked_today1} out of ${dns_queries_today1} queries"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Latest:" "${latest_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Ad:" "${top_blocked}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Dmn:" "${top_domain}"
    CleanPrintf " %-10s%-39s\e[0K\\n" "Top Clnt:" "${top_client}"
    CleanEcho "FTL ==========================================================================="
    CleanPrintf " %-10s%-9s %-10s%-9s %-10s%-9s\e[0K\\n" "PID:" "${ftlPID}" "CPU Use:" "${ftl_cpu}%" "Mem. Use:" "${ftl_mem_percentage}%"
    CleanPrintf " %-10s%-69s\e[0K\\n" "DNSCache:" "${cache_inserts} insertions, ${cache_evictions} deletions, ${cache_size} total entries"
  fi
}

PrintSystemInformation() {
  if [ "$1" = "pico" ]; then
    CleanEcho "${bold_text}CPU ================${reset_text}"
    echo -ne "${ceol} [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
  elif [ "$1" = "nano" ]; then
    CleanEcho "${ceol}${bold_text}SYSTEM =================${reset_text}"
    CleanEcho " Up:  ${system_uptime}"
    echo -ne  "${ceol} CPU: [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
  elif [ "$1" = "micro" ]; then
    CleanEcho "${bold_text}SYSTEM =======================${reset_text}"
    CleanEcho " Uptime:  ${system_uptime}"
    CleanEcho " Load:    [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
    echo -ne "${ceol}Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
  elif [ "$1" = "mini" ]; then
    CleanEcho "${bold_text}SYSTEM =================================${reset_text}"
    CleanPrintf " %-9s%-29s\\n" "Uptime:" "${system_uptime}"
    CleanEcho " Load:    [${cpu_load_1_heatmap}${cpu_bar}${reset_text}] ${cpu_percent}%"
    echo -ne "${ceol}Memory:  [${memory_heatmap}${memory_bar}${reset_text}] ${memory_percent}%"
  elif [ "$1" = "tiny" ]; then
    CleanEcho "${bold_text}SYSTEM =============================================${reset_text}"
    CleanPrintf " %-10s%-29s\e[0K\\n" "Uptime:" "${system_uptime}"
    CleanPrintf " %-10s${temp_heatmap}%-17s${reset_text} %-8s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-4s${reset_text}\e[0K\\n" "CPU Temp:" "${temperature}" "Load:" "${cpu_load[0]}" "${cpu_load[1]}" "${cpu_load[2]}"
    # Memory and CPU bar
    CleanPrintf " %-10s[${memory_heatmap}%-7s${reset_text}] %-6s %-8s[${cpu_load_1_heatmap}%-7s${reset_text}] %-5s" "Memory:" "${memory_bar}" "${memory_percent}%" "CPU:" "${cpu_bar}" "${cpu_percent}%"
  # else we're not
  elif [[ "$1" = "regular" || "$1" = "slim" ]]; then
    CleanEcho "${bold_text}SYSTEM ====================================================${reset_text}"
    # Uptime
    CleanPrintf " %-10s%-39s\e[0K\\n" "Uptime:" "${system_uptime}"

    # Temp and Loads
    CleanPrintf " %-10s${temp_heatmap}%-20s${reset_text}" "CPU Temp:" "${temperature}"
    CleanPrintf " %-10s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-4s${reset_text}\e[0K\\n" "CPU Load:" "${cpu_load[0]}" "${cpu_load[1]}" "${cpu_load[2]}"

    # Memory and CPU bar
    CleanPrintf " %-10s[${memory_heatmap}%-10s${reset_text}] %-6s %-10s[${cpu_load_1_heatmap}%-10s${reset_text}] %-5s" "Memory:" "${memory_bar}" "${memory_percent}%" "CPU Load:" "${cpu_bar}" "${cpu_percent}%"
  else
    CleanEcho "${bold_text}SYSTEM ========================================================================${reset_text}"
    # Uptime and memory
    CleanPrintf " %-10s%-39s %-10s[${memory_heatmap}%-10s${reset_text}] %5s\\n" "Uptime:" "${system_uptime}" "Memory:" "${memory_bar}" "${memory_percent}%"

    # CPU temp, load, percentage
    CleanPrintf " %-10s${temp_heatmap}%-10s${reset_text} %-10s${cpu_load_1_heatmap}%-4s${reset_text}, ${cpu_load_5_heatmap}%-4s${reset_text}, ${cpu_load_15_heatmap}%-7s${reset_text} %-10s[${memory_heatmap}%-10s${reset_text}] %5s" "CPU Temp:" "${temperature}" "CPU Load:" "${cpu_load[0]}" "${cpu_load[1]}" "${cpu_load[2]}" "CPU Load:" "${cpu_bar}" "${cpu_percent}%"
  fi
}

############################################# HELPERS ##############################################

# Provides a color based on a provided percentage
# takes in one or two parameters
HeatmapGenerator () {
  # if one number is provided, just use that percentage to figure out the colors
  if [ -z "$2" ]; then
    load=$(printf "%.0f" "$1")
  # if two numbers are provided, do some math to make a percentage to figure out the colors
  else
    load=$(printf "%.0f" "$(echo "$1 $2" | awk '{print ($1 / $2) * 100}')")
  fi

  # Color logic
  #  |<-                 green                  ->| yellow |  red ->
  #  0  5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100
  if [ "${load}" -lt 75 ]; then
    out=${green_text}
  elif [ "${load}" -lt 90 ]; then
    out=${yellow_text}
  else
    out=${red_text}
  fi

  echo "$out"
}

# Provides a "bar graph"
# takes in two or three parameters
# $1: percentage filled
# $2: max length of the bar
# $3: colored flag, if "color" backfill with color
BarGenerator() {
  # number of filled in cells in the bar
  barNumber=$(printf %.f "$(echo "$1 $2" | awk '{print ($1 / 100) * $2}')")
  frontFill=$(for i in $(seq "$barNumber"); do echo -n '■'; done)

  # remaining "unfilled" cells in the bar
  backfillNumber=$(($2-barNumber))

  # if the filled in cells is less than the max length of the bar, fill it
  if [ "$barNumber" -lt "$2" ]; then
    # if the bar should be colored
    if [ "$3" = "color" ]; then
      # fill the rest in color
      backFill=$(for i in $(seq $backfillNumber); do echo -n '■'; done)
      out="${red_text}${frontFill}${green_text}${backFill}${reset_text}"
    # else, it shouldn't be colored in
    else
      # fill the rest with "space"
      backFill=$(for i in $(seq $backfillNumber); do echo -n '·'; done)
      out="${frontFill}${reset_text}${backFill}"
    fi
  # else, fill it all the way
  else
    out=$(for i in $(seq "$2"); do echo -n '■'; done)
  fi

  echo "$out"
}

# Checks the size of the screen and sets the value of padd_size
SizeChecker(){
  console_width=$(tput cols)
  console_height=$(tput lines)
  # Below Pico. Gives you nothing...
  if [[ "$console_width" -lt "20" || "$console_height" -lt "10" ]]; then
    # Nothing is this small, sorry
    clear
    echo -e "${check_box_bad} Error!\\n    PADD isn't\\n    for ants!"
    exit 1
  # Below Nano. Gives you Pico.
  elif [[ "$console_width" -lt "24" || "$console_height" -lt "12" ]]; then
    padd_size="pico"
  # Below Micro, Gives you Nano.
  elif [[ "$console_width" -lt "30" || "$console_height" -lt "16" ]]; then
    padd_size="nano"
  # Below Mini. Gives you Micro.
  elif [[ "$console_width" -lt "40" || "$console_height" -lt "18" ]]; then
    padd_size="micro"
  # Below Tiny. Gives you Mini.
  elif [[ "$console_width" -lt "53" || "$console_height" -lt "20" ]]; then
      padd_size="mini"
  # Below Slim. Gives you Tiny.    
  elif [[ "$console_width" -lt "60" || "$console_height" -lt "21" ]]; then
      padd_size="tiny"    
  # Below Regular. Gives you Slim.
  elif [[ "$console_width" -lt "80" || "$console_height" -lt "26" ]]; then
    if [[ "$console_height" -lt "22" ]]; then
      padd_size="slim"
    else
      padd_size="regular"
    fi
  # Mega
  else
    padd_size="mega"
  fi
  # Center the output (default position)
    xOffset="$(( (console_width - width) / 2 ))"
    yOffset="$(( (console_height - height) / 2 ))"
}

CheckConnectivity() {
  connectivity="false"
  connection_attempts=1
  wait_timer=1

  while [ $connection_attempts -lt 9 ]; do

    if nc -zw1 google.com 443 2>/dev/null; then
      if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
        echo "Attempt #${connection_attempts} passed..."
      elif [ "$1" = "mini" ]; then
        echo "Attempt ${connection_attempts} passed."
      else
        echo "  - Attempt ${connection_attempts} passed...                                     "
      fi

      connectivity="true"
      connection_attempts=11
    else
      connection_attempts=$((connection_attempts+1))

      inner_wait_timer=$((wait_timer*1))

      # echo "$wait_timer = $inner_wait_timer"
      while [ $inner_wait_timer -gt 0 ]; do
        if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
          echo -ne "Attempt #${connection_attempts} failed...\\r"
        elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
          echo -ne "- Attempt ${connection_attempts} failed, wait ${inner_wait_timer}  \\r"
        else
          echo -ne "  - Attempt ${connection_attempts} failed... waiting ${inner_wait_timer} seconds...  \\r"
        fi
        sleep 1
        inner_wait_timer=$((inner_wait_timer-1))
      done

      # echo -ne "Attempt $connection_attempts failed... waiting $wait_timer seconds...\\r"
      # sleep $wait_timer
      wait_timer=$((wait_timer*2))
    fi

  done

  if [ "$connectivity" = "false" ]; then
    if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
      echo "Check failed..."
    elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
      echo "- Connectivity check failed."
    else
      echo "  - Connectivity check failed..."
    fi
  else
    if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
      echo "Check passed..."
    elif [ "$1" = "mini" ] || [ "$1" = "tiny" ]; then
      echo "- Connectivity check passed."
    else
      echo "  - Connectivity check passed..."
    fi
  fi
}

# Credit: https://stackoverflow.com/a/46324904
json_extract() {
    local key=$1
    local json=$2

    local string_regex='"([^"\]|\\.)*"'
    local number_regex='-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?'
    local value_regex="${string_regex}|${number_regex}|true|false|null"
    local pair_regex="\"${key}\"[[:space:]]*:[[:space:]]*(${value_regex})"

     if [[ ${json} =~ ${pair_regex} ]]; then
        # remove leading and trailing quotes
        sed -e 's/^"//' -e 's/"$//' <<<"${BASH_REMATCH[1]}"
     else
        return 1
    fi
}

# get the Telnet API Port FTL is using by parsing `pihole-FTL.conf`
# same implementation as https://github.com/pi-hole/pi-hole/pull/4945
getFTLAPIPort(){
    local FTLCONFFILE="/etc/pihole/pihole-FTL.conf"
    #local DEFAULT_FTL_PORT=4711
    local DEFAULT_FTL_PORT=8080
    local ftl_api_port

    if [ -s "$FTLCONFFILE" ]; then
        # if FTLPORT is not set in pihole-FTL.conf, use the default port
        ftl_api_port="$({ grep '^FTLPORT=' "${FTLCONFFILE}" || echo "${DEFAULT_FTL_PORT}"; } | cut -d'=' -f2-)"
        # Exploit prevention: set the port to the default port if there is malicious (non-numeric)
        # content set in pihole-FTL.conf
        expr "${ftl_api_port}" : "[^[:digit:]]" > /dev/null && ftl_api_port="${DEFAULT_FTL_PORT}"
    else
        # if there is no pihole-FTL.conf, use the default port
        ftl_api_port="${DEFAULT_FTL_PORT}"
    fi

    echo "${ftl_api_port}"

}

# converts a given version string e.g. v3.7.1 to 3007001000 to allow for easier comparison of multi digit version numbers
# credits https://apple.stackexchange.com/a/123408
VersionConverter() {
  echo "$@" | tr -d '[:alpha:]' | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

moveYOffset(){
    # moves the cursor yOffset-times down
    # https://vt100.net/docs/vt510-rm/CUD.html
    # this needs to be guarded, because if the amount is 0, it is adjusted to 1
    # https://terminalguide.namepad.de/seq/csi_cb/

    #if [ "${yOffset}" -gt 0 ]; then
    #    printf '\e[%sB' "${yOffset}"
    #fi
    echo ""
}

moveXOffset(){
    # moves the cursor xOffset-times to the right
    # https://vt100.net/docs/vt510-rm/CUF.html
    # this needs to be guarded, because if the amount is 0, it is adjusted to 1
    # https://terminalguide.namepad.de/seq/csi_cb/

    #if [ "${xOffset}" -gt 0 ]; then
    #    printf '\e[%sC' "${xOffset}"
    #fi
    echo ""
}

# Remove undesired strings from sys_model variable - used in GetSystemInformation() function
filterModel() {
    FILTERLIST="To be filled by O.E.M.|Not Applicable|System Product Name|System Version|Undefined|Default string|Not Specified|Type1ProductConfigId|INVALID|All Series|�"

    # Description:
    #    `-v`      : set $FILTERLIST into a variable called `list`
    #    `gsub()`  : replace all list items (ignoring case) with an empty string, deleting them
    #    `{$1=$1}1`: remove all extra spaces. The last "1" evaluates as true, printing the result
    echo "$1" | awk -v list="$FILTERLIST" '{IGNORECASE=1; gsub(list,"")}; {$1=$1}1'
}

# Truncates a given string and appends three '...'
# takes two parameters
# $1: string to truncate
# $2: max length of the string
truncateString() {
    local truncatedString length shorted

    length=${#1}
    shorted=$(($2-3)) # shorten max allowed length by 3 to make room for the dots
    if [ "${length}" -gt "$2" ]; then
        # if length of the string is larger then the specified max length
        # cut every char from the string exceeding length $shorted and add three dots
        truncatedString=$(echo "$1" | cut -c1-$shorted)"..."
        echo "${truncatedString}"
    else
        echo "$1"
    fi
}

# Converts seconds to days, hours, minutes
# https://unix.stackexchange.com/a/338844
convertUptime() {
    # shellcheck disable=SC2016
    eval "echo $(date -ud "@$1" +'$((%s/3600/24)) days, %H hours, %M minutes')"
}


secretRead() {

    # POSIX compliant function to read user-input and
    # mask every character entered by (*)
    #
    # This is challenging, because in POSIX, `read` does not support
    # `-s` option (suppressing the input) or
    # `-n` option (reading n chars)


    # This workaround changes the terminal characteristics to not echo input and later resets this option
    # credits https://stackoverflow.com/a/4316765
    # showing asterisk instead of password
    # https://stackoverflow.com/a/24600839
    # https://unix.stackexchange.com/a/464963

    stty -echo # do not echo user input
    stty -icanon min 1 time 0 # disable canonical mode https://man7.org/linux/man-pages/man3/termios.3.html

    unset password
    unset key
    unset charcount
    charcount=0
    while key=$(dd ibs=1 count=1 2>/dev/null); do #read one byte of input
        if [ "${key}" = "$(printf '\0' | tr -d '\0')" ] ; then
            # Enter - accept password
            break
        fi
        if [ "${key}" = "$(printf '\177')" ] ; then
            # Backspace
            if [ $charcount -gt 0 ] ; then
                charcount=$((charcount-1))
                printf '\b \b'
                password="${password%?}"
            fi
        else
            # any other character
            charcount=$((charcount+1))
            printf '*'
            password="$password$key"
        fi
    done

    # restore original terminal settings
    stty "${stty_orig}"
}

########################################## MAIN FUNCTIONS ##########################################

OutputJSON() {
  GetSummaryInformation
  echo "{\"domains_being_blocked\":${domains_being_blocked_raw},\"dns_queries_today\":${dns_queries_today_raw},\"ads_blocked_today\":${ads_blocked_today_raw},\"ads_percentage_today\":${ads_percentage_today_raw}}"
}

StartupRoutine(){
  if [ "$1" = "pico" ] || [ "$1" = "nano" ] || [ "$1" = "micro" ]; then
    PrintLogo "$1"
    echo -e "START-UP ==========="
    echo -e "Checking connection."
    CheckConnectivity "$1"
    echo -e "Starting PADD..."
    
    # Get PID of PADD
    pid=$$
    echo -ne " [¦·········]  10%\\r"
    echo ${pid} > ./PADD.pid

    # Check for updates
    echo -ne " [¦¦········]  20%\\r"
    if [ -e "piHoleVersion" ]; then
      rm -f piHoleVersion
      echo -ne " [¦¦¦·······]  30%\\r"
    else
      echo -ne " [¦¦¦·······]  30%\\r"
    fi

    # Get our information for the first time
    echo -ne " [¦¦¦¦······]  40%\\r"
    GetSystemInformation "$1"
    echo -ne " [¦¦¦¦¦·····]  50%\\r"
    GetSummaryInformation "$1"
    echo -ne " [¦¦¦¦¦¦····]  60%\\r"
    GetPiholeInformation "$1"
    echo -ne " [¦¦¦¦¦¦¦···]  70%\\r"
    GetNetworkInformation "$1"
    echo -ne " [¦¦¦¦¦¦¦¦··]  80%\\r"
    GetVersionInformation "$1"
    echo -ne " [¦¦¦¦¦¦¦¦¦·]  90%\\r"
    echo -ne " [¦¦¦¦¦¦¦¦¦¦] 100%\\n"

  elif [ "$1" = "mini" ]; then
    PrintLogo "$1"
    echo "START UP ====================="
    echo "Checking connectivity."
    CheckConnectivity "$1"

    echo "Starting PADD."
    # Get PID of PADD
    pid=$$
    echo "- Writing PID (${pid}) to file."
    echo ${pid} > ./PADD.pid

    # Check for updates
    echo "- Checking for version file."
    if [ -e "piHoleVersion" ]; then
      echo "  - Found and deleted."
      rm -f piHoleVersion
    else
      echo "  - Not found."
    fi

    # Get our information for the first time
    echo "- Gathering system info."
    GetSystemInformation "mini"
    echo "- Gathering Pi-hole info."
    GetSummaryInformation "mini"
    echo "- Gathering network info."
    GetNetworkInformation "mini"
    echo "- Gathering version info."
    GetVersionInformation "mini"
    echo "  - Core v$core_version, Web v$web_version"
    echo "  - FTL v$ftl_version, PADD $padd_version"
    echo "  - $version_status"

  else
    echo -e "${padd_logo_retro_1}"
    echo -e "${padd_logo_retro_2}Pi-hole® Ad Detection Display"
    echo -e "${padd_logo_retro_3}A client for Pi-hole\\n"
    if [ "$1" = "tiny" ]; then
      echo "START UP ============================================"
    else
      echo "START UP ==================================================="
    fi

    echo -e "- Checking internet connection..."
    CheckConnectivity "$1"

    # Get PID of PADD
    pid=$$
    echo "- Writing PID (${pid}) to file..."
    echo ${pid} > ./PADD.pid

    # Check for updates
    echo "- Checking for PADD version file..."
    if [ -e "piHoleVersion" ]; then
      echo "  - PADD version file found... deleting."
      rm -f piHoleVersion
    else
      echo "  - PADD version file not found."
    fi
   
    # Test if the authentication endpoint is available
    TestAPIAvailability

    # Authenticate with the FTL server
    moveXOffset; printf "%b" "Establishing connection with FTL...\n"
    LoginAPI

    # Get our information for the first time
    echo "- Gathering system information..."
    GetSystemInformation "$1"
    echo "- Gathering Pi-hole information..."
    GetSummaryInformation "$1"
    GetPiholeInformation "$1"
    echo "- Gathering network information..."
    GetNetworkInformation "$1"
    echo "- Gathering version information..."
    GetVersionInformation "$1"
    echo "  - Pi-hole Core v$core_version"
    echo "  - Web Admin v$web_version"
    echo "  - FTL v$ftl_version"
    echo "  - PADD $padd_version $padd_build"
    echo "  - $version_status"
    echo "  - CPU has $core_count cores"
    echo -e "  - IPv4:    ${IPV4_ADDRESS}"
  fi

  printf "%s" "- Starting in "

  for i in 3 2 1
  do
    printf "%s..." "$i"
    sleep 1
  done
}

PrintDZdata() {
    if hash ipsec 2>/dev/null; then
       count=$(sudo ipsec status | grep ESTABLISHED | wc -l)
    else    
        count="-%-"
    fi
    
    if [ "$count" = "" ] ; then
       count="Error"
    fi
    
    if [ "$count" = "No" ] ; then
       count="0"
    fi
    sshcount=$(netstat -tn | grep :22 | grep ESTABLISHED | wc -l)

    disk_percent=$(df -k | grep /dev/root | awk '{printf "%5.1f",$3/$2*100.0}')
  
    if [[ "$dzhost" != "" ]]; then
        wget -q --delete-after "http://$dzhost/json.htm?type=command&param=udevice&idx=$idxvpn&svalue=$count"
        wget -q --delete-after "http://$dzhost/json.htm?type=command&param=udevice&idx=$idxssh&svalue=$sshcount"
        wget -q --delete-after "http://$dzhost/json.htm?type=command&param=udevice&idx=$idxdisk&svalue=$disk_percent"
    fi
    
    if [[ "$count" != "0" ]] ; then
        count="${yellow_text}$count ${reset_text}"
    else 
        count="${green_text}$count ${reset_text}"
    fi
    
    if [[ "$sshcount" != "0" ]] ; then
        sshcount="${yellow_text}$sshcount ${reset_text}"
    else 
        sshcount="${green_text}$sshcount ${reset_text}"
    fi
    
    if [ ! -f $alarm1f ] 
    then
        alarm1c=${check_box_good}
        alarm1r=$alarm1o
    else
        if [ "$alarm1f" != "" ] 
        then 
             alarm1c=${check_box_bad}
             alarm1r=$alarm1e
        else
            alarm1c=" "
            alarm1r=" "
        fi
    fi
    
    if [ ! -f $alarm2f ] 
    then
        alarm2c=${check_box_good}
        alarm2r=$alarm2o
    else
        if [ "$alarm2f" != "" ] 
        then 
             alarm2c=${check_box_bad}
             alarm2r=$alarm2e
        else
            alarm2c=" "
            alarm2r=" "
        fi
    fi
    
    if [ ! -f $alarm3f ] 
    then
        alarm3c=${check_box_good}
        alarm3r=$alarm3o
    else
        if [ "$alarm3f" != "" ] 
        then 
             alarm3c=${check_box_bad}
             alarm3r=$alarm3e
        else
            alarm3c=" "
            alarm3r=" "
        fi
    fi
    
    if [ ! -f $alarm4f ] 
    then
        if [ $alarm4v = 0 ] 
             then
                  alarm4c=${check_box_bad}
                  alarm4r=$alarm4e
             else
                 alarm4c=${check_box_good}
                  alarm4r=$alarm4o
             fi
    else
        if [ "$alarm4f" != "" ] 
        then 
             if [ $alarm4v = 1 ] 
             then
                  alarm4c=${check_box_bad}
                  alarm4r=$alarm4e
             else
                 alarm4c=${check_box_good}
                  alarm4r=$alarm4o
             fi
        else
            alarm4c=" "
            alarm4r=" "
        fi
    fi
    
    disk_heatmap=$(HeatmapGenerator "${disk_percent}")
    disk_bar=$(BarGenerator "${disk_percent}" 10)
    # disk_percent="${green_text}$disk_percent%${reset_text}"
    disk_percent="$disk_percent%"
    
    CleanPrintf "\e[0K\\n "
    # CleanPrintf "VPNcount: %-20s SSHcount: %-30s Disk free: %-15s" "${count}" "${sshcount}" "${disk_percent}"
    CleanPrintf "VPNcount: %-18s SSHcount: %-28s Disk used:[${disk_heatmap}%-9s${reset_text}]%5s" "${count}" "${sshcount}" "${disk_bar}" "${disk_percent}"
    CleanPrintf "\e[0K\\n"
}

NormalPADD() {
  for (( ; ; )); do

    console_width=$(tput cols)
    console_height=$(tput lines)

    # Sizing Checks
    SizeChecker

    # Get Config variables
    . /etc/pihole/setupVars.conf

    # check if a new authentication is required (e.g. after connection to FTL has re-established)
    # GetFTLData() will return a 401 if a 401 http status code is returned
    # as $password should be set already, PADD should automatically re-authenticate
    authenthication_required=$(GetFTLData "info/ftl")
    if [ "${authenthication_required}" = 401 ]; then
      Authenticate
    fi

    # Move the cursor to top left of console to redraw
    tput cup 0 0

    # Output everything to the screen
    PrintLogo ${padd_size}
    PrintPiholeInformation ${padd_size}
    PrintPiholeStats ${padd_size}
    PrintNetworkInformation ${padd_size}
    PrintSystemInformation ${padd_size}
    
    PrintDZdata
    
    # Clear to end of screen (below the drawn dashboard)
    tput ed

    pico_status=${pico_status_ok}
    mini_status_=${mini_status_ok}
    tiny_status_=${tiny_status_ok}   

    # Start getting our information
    GetVersionInformation ${padd_size}
    GetPiholeInformation ${padd_size}
    GetNetworkInformation ${padd_size}
    GetSummaryInformation ${padd_size}
    GetSystemInformation ${padd_size}
    
    if [ -z "${delay}" ]; then
        delay=1
    fi
     
    # Sleep for 5 seconds
    # sleep 5
    if [[ "$padd_size" == "mega" ]] ; then 
      tput cup 3 0
      echo "${white_text}(${bold_text}${yellow_text}4${reset_text})" # "/"
      sleep $delay
      tput cup 3 0
      echo "${white_text}(${bold_text}${yellow_text}3${reset_text})" #"-"
      sleep $delay
      tput cup 3 0
      echo "${white_text}(${bold_text}${yellow_text}2${reset_text})" #"\\"
      sleep $delay
      tput cup 3 0
      echo "${white_text}(${bold_text}${yellow_text}1${reset_text})" #"|"
      sleep $delay
      #tput cup 3 0
      #echo "+"
    else 
        sleep 5
    fi
  done
}

DisplayHelp() {
  cat << EOM
::: PADD displays stats about your piHole!
:::
::: Note: If no option is passed, then stats are displayed on screen, updated every 5 seconds
:::
::: Options:
:::  -j, --json    output stats as JSON formatted string
:::  -h, --help    display this help text
EOM
    exit 0
}

main() {
  # Turns off the cursor
  # (From Pull request #8 https://github.com/jpmck/PADD/pull/8)
  setterm -cursor off
  trap "{ setterm -cursor on ; echo "" ; exit 0 ; }" SIGINT SIGTERM EXIT

  clear

  console_width=$(tput cols)
  console_height=$(tput lines)

  # Get Our Config Values
  # shellcheck disable=SC1091
  . /etc/pihole/setupVars.conf

  SizeChecker

  StartupRoutine ${padd_size}

  # Run PADD
  clear
  NormalPADD
}

#for var in "$@"; do
#  case "$var" in
#    "-j" | "--json"  ) OutputJSON;;
#    "-h" | "--help"  ) DisplayHelp;;
#    *                ) exit 1;;
#  esac
#done

# Process all options (if present)
while [ "$#" -gt 0 ]; do
  case "$1" in
    "-j" | "--json"     ) xOffset=0; OutputJSON; exit 0;;
    "-u" | "--update"   ) Update;;
    "-h" | "--help"     ) DisplayHelp; exit 0;;
    "-v" | "--version"  ) xOffset=0; ShowVersion; exit 0;;
    "--xoff"            ) xOffset="$2"; xOffOrig="$2"; shift;;
    "--yoff"            ) yOffset="$2"; yOffOrig="$2"; shift;;
    "--server"          ) SERVER="$2"; shift;;
    "--secret"          ) password="$2"; shift;;
    "--delay"           ) delay="$2" ; shift ;;
    *                   ) DisplayHelp; exit 1;;
  esac
  shift
done

main
