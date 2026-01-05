#!/bin/bash

################################################################################
# IP Address Reporter
# 
# Purpose: Determine and report internal and external IP addresses
# Author: Infrastructure Team
# Usage: ./ip_reporter.sh [options]
################################################################################

set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMEOUT=5
EXTERNAL_IP_SERVICES=(
    "https://api.ipify.org"
    "https://checkip.amazonaws.com"
    "https://icanhazip.com"
    "https://ifconfig.me"
)

################################################################################
# Helper Functions
################################################################################

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate IP address format
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

################################################################################
# Internal IP Detection Functions
################################################################################

# Get internal IP using hostname command
get_internal_ip_hostname() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

# Get internal IP using primary interface
get_internal_ip_interface() {
    # Try to get the primary interface (usually the one with a default route)
    local primary_interface=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1)
    
    if [[ -n "$primary_interface" ]]; then
        ip addr show "$primary_interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1
    fi
}

# Get internal IP using ifconfig (fallback)
get_internal_ip_ifconfig() {
    ifconfig 2>/dev/null | grep -A1 "inet " | grep "inet" | grep -v "127.0.0.1" | awk '{print $2}' | head -n1
}

# Get internal IP using alternative method
get_internal_ip_getent() {
    getent hosts $(hostname) 2>/dev/null | awk '{print $1}' | grep -v "^127"
}

# Main internal IP detection with fallbacks
get_internal_ip() {
    local internal_ip=""
    
    # Try hostname command first
    internal_ip=$(get_internal_ip_hostname)
    [[ -n "$internal_ip" ]] && validate_ip "$internal_ip" && echo "$internal_ip" && return 0
    
    # Try ip command
    internal_ip=$(get_internal_ip_interface)
    [[ -n "$internal_ip" ]] && validate_ip "$internal_ip" && echo "$internal_ip" && return 0
    
    # Try ifconfig
    internal_ip=$(get_internal_ip_ifconfig)
    [[ -n "$internal_ip" ]] && validate_ip "$internal_ip" && echo "$internal_ip" && return 0
    
    # Try getent
    internal_ip=$(get_internal_ip_getent)
    [[ -n "$internal_ip" ]] && validate_ip "$internal_ip" && echo "$internal_ip" && return 0
    
    return 1
}

################################################################################
# External IP Detection Functions
################################################################################

# Get external IP using curl
get_external_ip_curl() {
    local service=$1
    curl -s --max-time "$TIMEOUT" "$service" 2>/dev/null | tr -d '\n'
}

# Get external IP using wget
get_external_ip_wget() {
    local service=$1
    wget -qO- --timeout="$TIMEOUT" "$service" 2>/dev/null | tr -d '\n'
}

# Main external IP detection with multiple services and fallbacks
get_external_ip() {
    local external_ip=""
    
    # Check if curl is available
    if command -v curl &>/dev/null; then
        for service in "${EXTERNAL_IP_SERVICES[@]}"; do
            external_ip=$(get_external_ip_curl "$service")
            [[ -n "$external_ip" ]] && validate_ip "$external_ip" && echo "$external_ip" && return 0
        done
    fi
    
    # Fallback to wget if curl is not available
    if command -v wget &>/dev/null; then
        for service in "${EXTERNAL_IP_SERVICES[@]}"; do
            external_ip=$(get_external_ip_wget "$service")
            [[ -n "$external_ip" ]] && validate_ip "$external_ip" && echo "$external_ip" && return 0
        done
    fi
    
    return 1
}

################################################################################
# Network Interface Information
################################################################################

get_network_interfaces() {
    print_info "Network Interfaces:"
    
    if command -v ip &>/dev/null; then
        ip -br addr show 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    elif command -v ifconfig &>/dev/null; then
        ifconfig 2>/dev/null | grep -E "^[a-zA-Z0-9]" | awk '{print $1}'  | while read -r iface; do
            echo "  $iface"
        done
    fi
}

################################################################################
# Main Reporting Function
################################################################################

report_ips() {
    echo ""
    echo "==============================================="
    echo "         IP Address Report"
    echo "==============================================="
    echo ""
    
    # Get internal IP
    print_info "Detecting internal IP address..."
    local internal_ip=$(get_internal_ip)
    
    if [[ -n "$internal_ip" ]]; then
        print_success "Internal IP: $internal_ip"
    else
        print_error "Could not determine internal IP address"
    fi
    
    echo ""
    
    # Get external IP
    print_info "Detecting external IP address..."
    local external_ip=$(get_external_ip)
    
    if [[ -n "$external_ip" ]]; then
        print_success "External IP: $external_ip"
    else
        print_error "Could not determine external IP address (requires internet connectivity)"
    fi
    
    echo ""
    echo "==============================================="
    
    # Get hostname
    print_info "Hostname: $(hostname)"
    
    echo ""
    
    # Show network interfaces
    get_network_interfaces
    
    echo ""
    echo "==============================================="
    echo ""
    
    # Return status
    if [[ -n "$internal_ip" ]] && [[ -n "$external_ip" ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Argument Parsing
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -i, --internal      Show only internal IP address
    -e, --external      Show only external IP address
    -q, --quiet         Suppress colored output and additional info
    -h, --help          Display this help message

Examples:
    $0                  # Full report with all information
    $0 --internal       # Show only internal IP
    $0 --external       # Show only external IP
    $0 --quiet          # Plain text report

EOF
}

################################################################################
# Script Entry Point
################################################################################

main() {
    local mode="full"
    local quiet=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--internal)
                mode="internal"
                shift
                ;;
            -e|--external)
                mode="external"
                shift
                ;;
            -q|--quiet)
                quiet=1
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Suppress colors if quiet mode
    if [[ $quiet -eq 1 ]]; then
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
    fi
    
    # Execute based on mode
    case $mode in
        internal)
            local ip=$(get_internal_ip)
            if [[ -n "$ip" ]]; then
                echo "$ip"
                exit 0
            else
                print_error "Could not determine internal IP"
                exit 1
            fi
            ;;
        external)
            local ip=$(get_external_ip)
            if [[ -n "$ip" ]]; then
                echo "$ip"
                exit 0
            else
                print_error "Could not determine external IP"
                exit 1
            fi
            ;;
        full)
            report_ips
            exit $?
            ;;
    esac
}

# Run main function
main "$@"