#!/bin/zsh

# Cloudinary Batch Upload Script
# Usage: ./cloudinary_upload.sh <directory_path> [log_file]

# Configuration - Set these variables or export them as environment variables
CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-lifeway-int}"
CLOUDINARY_API_KEY="${CLOUDINARY_API_KEY:-452865665351593}"
CLOUDINARY_API_SECRET="${CLOUDINARY_API_SECRET:-heUeCQFTdqIjiQRKJkmGXobPb70}"
UPLOAD_PRESET="VBS"

# Script parameters
DIRECTORY="${1:?Error: Please specify a directory path}"
LOG_FILE="${2:-$HOME/Desktop/cloudinary_upload_$(date +%Y%m%d_%H%M%S).log}"

# Counters
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Function to validate Cloudinary credentials
validate_credentials() {
    if [[ -z "$CLOUDINARY_CLOUD_NAME" || "$CLOUDINARY_CLOUD_NAME" == "your_cloud_name" ]]; then
        print_status $RED "Error: CLOUDINARY_CLOUD_NAME not set"
        exit 1
    fi
    # API key and secret are REQUIRED for signed upload presets
    if [[ -z "$CLOUDINARY_API_KEY" || "$CLOUDINARY_API_KEY" == "your_api_key" ]]; then
        print_status $RED "Error: CLOUDINARY_API_KEY required for signed upload preset"
        exit 1
    fi
    if [[ -z "$CLOUDINARY_API_SECRET" || "$CLOUDINARY_API_SECRET" == "your_api_secret" ]]; then
        print_status $RED "Error: CLOUDINARY_API_SECRET required for signed upload preset"
        exit 1
    fi
}

# Function to check if curl is installed
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_status $RED "Error: curl is required but not installed"
        exit 1
    fi
}

# Function to upload file to Cloudinary
upload_file() {
    local file_path=$1
    local file_name=$(basename "$file_path")
    
    print_status $BLUE "Uploading: $file_name"
    
    # Generate timestamp for signature
    local timestamp=$(date +%s)
    
    # Create parameters for signature (sorted alphabetically)
    local params="timestamp=${timestamp}&upload_preset=${UPLOAD_PRESET}"
    
    # Create signature string by appending API secret
    local signature_string="${params}${CLOUDINARY_API_SECRET}"
    
    # Generate SHA1 signature
    local signature=$(echo -n "$signature_string" | shasum -a 1 | cut -d' ' -f1)
    
    # Upload to Cloudinary with signed preset
    local response=$(curl -s -X POST \
        -F "file=@${file_path}" \
        -F "upload_preset=${UPLOAD_PRESET}" \
        -F "timestamp=${timestamp}" \
        -F "api_key=${CLOUDINARY_API_KEY}" \
        -F "signature=${signature}" \
        "https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload")
    
    # Check if upload was successful
    if echo "$response" | grep -q '"public_id"'; then
        local public_id=$(echo "$response" | grep -o '"public_id":"[^"]*' | cut -d'"' -f4)
        local secure_url=$(echo "$response" | grep -o '"secure_url":"[^"]*' | cut -d'"' -f4)
        
        print_status $GREEN "✓ Success: $file_name"
        log_message "SUCCESS: $file_path -> Public ID: $public_id | URL: $secure_url"
        ((SUCCESS_COUNT++))
    else
        local error_message=$(echo "$response" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
        if [[ -z "$error_message" ]]; then
            error_message="Unknown error occurred"
        fi
        
        print_status $RED "✗ Failed: $file_name - $error_message"
        log_message "FAILURE: $file_path - Error: $error_message"
        log_message "FAILURE_RESPONSE: $response"
        ((FAILURE_COUNT++))
    fi
    
    ((TOTAL_COUNT++))
}

# Function to process directory
process_directory() {
    if [[ ! -d "$DIRECTORY" ]]; then
        print_status $RED "Error: Directory '$DIRECTORY' does not exist"
        exit 1
    fi
    
    print_status $YELLOW "Processing directory: $DIRECTORY"
    print_status $YELLOW "Log file: $LOG_FILE"
    
    # Initialize log file
    log_message "=== Cloudinary Upload Session Started ==="
    log_message "Directory: $DIRECTORY"
    log_message "Upload Preset: $UPLOAD_PRESET"
    
    # Find all files in directory (not subdirectories by default)
    # Use **/* if you want to include subdirectories recursively
    local files=()
    for file in "$DIRECTORY"/*; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done
    
    if [[ ${#files[@]} -eq 0 ]]; then
        print_status $YELLOW "No files found in directory"
        log_message "No files found in directory"
        return
    fi
    
    print_status $BLUE "Found ${#files[@]} files to upload"
    log_message "Found ${#files[@]} files to upload"
    
    # Process each file
    for file in "${files[@]}"; do
        upload_file "$file"
        # Small delay to avoid rate limiting
        sleep 0.5
    done
}

# Function to print summary
print_summary() {
    echo
    print_status $BLUE "=== Upload Summary ==="
    print_status $GREEN "Successful uploads: $SUCCESS_COUNT"
    print_status $RED "Failed uploads: $FAILURE_COUNT"
    print_status $BLUE "Total files processed: $TOTAL_COUNT"
    print_status $YELLOW "Log file: $LOG_FILE"
    
    log_message "=== Upload Summary ==="
    log_message "Successful uploads: $SUCCESS_COUNT"
    log_message "Failed uploads: $FAILURE_COUNT"
    log_message "Total files processed: $TOTAL_COUNT"
    log_message "=== Session Completed ==="
}

# Main execution
main() {
    print_status $BLUE "Starting Cloudinary batch upload..."
    
    # Validate inputs and dependencies
    check_dependencies
    validate_credentials
    
    # Process the directory
    process_directory
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [[ $FAILURE_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Handle script interruption
trap 'print_status $RED "\nScript interrupted. Check log file: $LOG_FILE"; exit 130' INT TERM

# Run main function
main "$@"