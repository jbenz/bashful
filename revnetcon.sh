#!/bin/bash

# Configuration file path
CONFIG_FILE="${1:-.}/config.ini"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at $CONFIG_FILE" >&2
    exit 1
fi

# Parse ignore_ip and ignore_subnet values from config.ini
declare -a IGNORE_IPS
declare -a IGNORE_SUBNETS
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    # Trim whitespace
    key="${key// /}"
    value="${value// /}"
    
    if [[ "$key" == "ignore_ip" ]]; then
        IGNORE_IPS+=("$value")
    elif [[ "$key" == "ignore_subnet" ]]; then
        IGNORE_SUBNETS+=("$value")
    fi
done < "$CONFIG_FILE"

# Build awk variable with ignore IPs (pipe-separated for regex alternation)
IGNORE_PATTERN=$(IFS='|'; echo "${IGNORE_IPS[*]}")
IGNORE_PATTERN="${IGNORE_PATTERN//./\\.}"

# Convert subnets to awk format (base|mask)
SUBNET_DATA=""
for subnet in "${IGNORE_SUBNETS[@]}"; do
    SUBNET_DATA+="$subnet "
done

# Run lsof with awk, passing the ignore pattern and subnets
export IGNORE_PATTERN SUBNET_DATA
sudo lsof -i TCP -s TCP:ESTABLISHED -nP | awk '
BEGIN {
    # Color codes
    GREY = "\033[90m"
    WHITE = "\033[37m"
    GREEN = "\033[32m"
    RED_BG_WHITE = "\033[41;97m"
    RESET = "\033[0m"
    
    # Ignore pattern from environment
    ignore_pattern = ENVIRON["IGNORE_PATTERN"]
    subnet_data = ENVIRON["SUBNET_DATA"]
    
    # Parse CIDR subnets
    subnet_count = 0
    if (subnet_data != "") {
        n = split(subnet_data, subnets_array)
        for (i = 1; i <= n; i++) {
            if (subnets_array[i] != "") {
                subnet_count++
                subnets[subnet_count] = subnets_array[i]
            }
        }
    }
}

# Function to check if IP is in CIDR subnet
function ip_in_subnet(ip, cidr,    base, mask, ip_parts, base_parts, i, ip_num, base_num) {
    # Split CIDR into base and mask
    if (split(cidr, cidr_parts, "/") != 2) return 0
    
    base = cidr_parts[1]
    mask = cidr_parts[2]
    
    # Split IPs into octets
    split(ip, ip_parts, "\\.")
    split(base, base_parts, "\\.")
    
    # Convert to 32-bit numbers and compare
    ip_num = (ip_parts[1] * 256^3) + (ip_parts[2] * 256^2) + (ip_parts[3] * 256) + ip_parts[4]
    base_num = (base_parts[1] * 256^3) + (base_parts[2] * 256^2) + (base_parts[3] * 256) + base_parts[4]
    
    # Create mask
    if (mask == 32) {
        net_mask = 4294967295
    } else if (mask == 0) {
        net_mask = 0
    } else {
        net_mask = and(4294967295, compl(2^(32 - mask) - 1))
    }
    
    return (and(ip_num, net_mask) == and(base_num, net_mask))
}

NR == 1 { print; next }
{
    output = ""
    i = 1
    while (i <= length($0)) {
        # Look for IP pattern
        if (match(substr($0, i), /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
            # Add text before IP
            output = output substr($0, i, RSTART - 1)
            ip = substr($0, i + RSTART - 1, RLENGTH)
            
            is_ignored = 0
            
            # Check if IP is in ignore list
            if (ignore_pattern != "" && ip ~ ignore_pattern) {
                is_ignored = 1
            }
            
            # Check if IP is in any ignore subnet
            if (!is_ignored && subnet_count > 0) {
                for (j = 1; j <= subnet_count; j++) {
                    if (ip_in_subnet(ip, subnets[j])) {
                        is_ignored = 1
                        break
                    }
                }
            }
            
            # Apply coloring
            if (is_ignored) {
                output = output GREY ip RESET
            } else if (ip ~ /^162\.248\.246\.[0-7]$/) {
                output = output GREY ip RESET
            } else if (ip ~ /^10\.20\.0\./) {
                output = output WHITE ip RESET
            } else if (ip ~ /^(10\.|192\.168\.|172\.)/) {
                output = output ip
            } else {
                # External IP - bright red background with white text
                output = output RED_BG_WHITE ip RESET
            }
            
            i = i + RSTART + RLENGTH - 1
        } else {
            output = output substr($0, i)
            break
        }
    }
    
    # Color ESTABLISHED
    gsub(/ESTABLISHED/, GREEN "ESTABLISHED" RESET, output)
    
    print output
}
'

