#!/bin/bash

################################################################################
# High-entropy password generator with flexible output options
#
# Features:
#   - Generate multiple high-entropy passwords
#   - Customizable password length
#   - Output to screen, file, or both
#   - Proper error handling and validation
#   - Quiet mode for piping
#   - Support for different character sets
#
# Usage: ./genpw.sh [OPTIONS]
#
# Options:
#   -n, --number N        Number of passwords to generate (default: 1)
#   -l, --length L        Password length (default: 16, minimum: 8)
#   -o, --output FILE     Write to file (if not set, output to screen)
#   -a, --append          Append to file instead of overwriting
#   -c, --charset TYPE    Character set: full, alphanumeric, or custom (default: full)
#   -q, --quiet           Suppress status messages (only passwords output)
#   -h, --help            Display this help message
#
# Examples:
#   ./genpw.sh -n 5 -l 20                    # 5 passwords, 20 chars, to screen
#   ./genpw.sh -n 10 -l 16 -o passwords.txt  # 10 passwords, to file
#   ./genpw.sh -n 5 -o creds.txt -a          # 5 passwords, append to file
#
# Exit codes:
#   0 - Success
#   1 - Invalid argument
#   2 - File write error
#   3 - Permission denied
#
################################################################################

set -u  # Exit on undefined variable
IFS=$'\n'  # Handle spaces in variables properly

# Default values
NUM_PASSWORDS=1
PASSWORD_LENGTH=16
OUTPUT_FILE=""
APPEND_MODE=false
CHARSET_TYPE="full"
QUIET_MODE=false
SCRIPT_NAME=$(basename "$0")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

################################################################################
# Function: Display usage information
################################################################################
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -n, --number N        Number of passwords to generate (default: 1)
  -l, --length L        Password length (default: 16, minimum: 8)
  -o, --output FILE     Write to file (if not set, output to screen)
  -a, --append          Append to file instead of overwriting
  -c, --charset TYPE    Character set:
                          full        - All special characters (default)
                          alphanumeric- Letters and numbers only
  -q, --quiet           Suppress status messages
  -h, --help            Display this help message

Examples:
  ${SCRIPT_NAME} -n 5 -l 20
  ${SCRIPT_NAME} -n 10 -l 16 -o passwords.txt
  ${SCRIPT_NAME} -n 5 -o creds.txt -a

EOF
}

################################################################################
# Function: Print error message to stderr
################################################################################
error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

################################################################################
# Function: Print info message (respects quiet mode)
################################################################################
info() {
    if [ "${QUIET_MODE}" = false ]; then
        echo -e "${YELLOW}INFO: $*${NC}" >&2
    fi
}

################################################################################
# Function: Print success message (respects quiet mode)
################################################################################
success() {
    if [ "${QUIET_MODE}" = false ]; then
        echo -e "${GREEN}✓ $*${NC}" >&2
    fi
}

################################################################################
# Function: Validate integer input
################################################################################
validate_integer() {
    local value=$1
    local min=${2:-1}
    local max=${3:-999999}
    local name=$4
    
    if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
        error "${name} must be a positive integer (got: ${value})"
        return 1
    fi
    
    if [ "${value}" -lt "${min}" ]; then
        error "${name} must be >= ${min} (got: ${value})"
        return 1
    fi
    
    if [ "${value}" -gt "${max}" ]; then
        error "${name} must be <= ${max} (got: ${value})"
        return 1
    fi
    
    return 0
}

################################################################################
# Function: Generate a single password
################################################################################
generate_password() {
    local length=$1
    local charset=$2
    local password
    
    case "${charset}" in
        alphanumeric)
            # Letters and numbers only
            password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "${length}")
            ;;
        full|*)
            # Full character set with special characters
            password=$(LC_ALL=C tr -dc "A-Za-z0-9!\"#\$%&'()*+,-./:;<=>?@[\\]^_\`{|}~" </dev/urandom 2>/dev/null | head -c "${length}")
            ;;
    esac
    
    echo "${password}"
}

################################################################################
# Function: Output password (to screen and/or file)
################################################################################
output_password() {
    local password=$1
    local count=$2
    
    # Output to screen
    echo "${password}"
    
    # Output to file if specified
    if [ -n "${OUTPUT_FILE}" ]; then
        if ! echo "${password}" >> "${OUTPUT_FILE}" 2>/dev/null; then
            error "Failed to write to file: ${OUTPUT_FILE}"
            return 2
        fi
    fi
    
    return 0
}

################################################################################
# Function: Main script logic
################################################################################
main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--number)
                NUM_PASSWORDS="${2:-}"
                if [ -z "${NUM_PASSWORDS}" ]; then
                    error "Option -n/--number requires an argument"
                    return 1
                fi
                shift 2
                ;;
            -l|--length)
                PASSWORD_LENGTH="${2:-}"
                if [ -z "${PASSWORD_LENGTH}" ]; then
                    error "Option -l/--length requires an argument"
                    return 1
                fi
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="${2:-}"
                if [ -z "${OUTPUT_FILE}" ]; then
                    error "Option -o/--output requires an argument"
                    return 1
                fi
                shift 2
                ;;
            -a|--append)
                APPEND_MODE=true
                shift
                ;;
            -c|--charset)
                CHARSET_TYPE="${2:-}"
                if [ -z "${CHARSET_TYPE}" ]; then
                    error "Option -c/--charset requires an argument"
                    return 1
                fi
                shift 2
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                error "Unknown option: $1"
                usage >&2
                return 1
                ;;
        esac
    done
    
    # Validate inputs
    if ! validate_integer "${NUM_PASSWORDS}" 1 1000 "Number of passwords"; then
        return 1
    fi
    
    if ! validate_integer "${PASSWORD_LENGTH}" 8 512 "Password length"; then
        return 1
    fi
    
    # Validate charset
    case "${CHARSET_TYPE}" in
        full|alphanumeric) ;;
        *)
            error "Unknown charset: ${CHARSET_TYPE}. Use 'full' or 'alphanumeric'"
            return 1
            ;;
    esac
    
    # Handle output file
    if [ -n "${OUTPUT_FILE}" ]; then
        # Check if we can write to the directory
        local output_dir
        output_dir=$(dirname "${OUTPUT_FILE}")
        if [ ! -d "${output_dir}" ]; then
            error "Output directory does not exist: ${output_dir}"
            return 1
        fi
        
        if [ ! -w "${output_dir}" ]; then
            error "Permission denied: cannot write to ${output_dir}"
            return 3
        fi
        
        # Handle file creation/append
        if [ "${APPEND_MODE}" = false ] && [ -f "${OUTPUT_FILE}" ]; then
            info "Overwriting existing file: ${OUTPUT_FILE}"
            : > "${OUTPUT_FILE}"  # Truncate file
        fi
        
        info "Generating ${NUM_PASSWORDS} password(s) (length: ${PASSWORD_LENGTH}, charset: ${CHARSET_TYPE})"
        [ -n "${OUTPUT_FILE}" ] && info "Writing to: ${OUTPUT_FILE}"
    else
        if [ "${QUIET_MODE}" = false ]; then
            info "Generating ${NUM_PASSWORDS} password(s) (length: ${PASSWORD_LENGTH}, charset: ${CHARSET_TYPE})"
        fi
    fi
    
    # Generate passwords
    local count=1
    while [ "${count}" -le "${NUM_PASSWORDS}" ]; do
        local password
        password=$(generate_password "${PASSWORD_LENGTH}" "${CHARSET_TYPE}")
        
        if ! output_password "${password}" "${count}"; then
            return 2
        fi
        
        ((count++))
    done
    
    # Success message
    success "Generated ${NUM_PASSWORDS} password(s)"
    
    return 0
}

# Run main function
main "$@"
exit $?
