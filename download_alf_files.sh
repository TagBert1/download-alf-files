#!/bin/bash

# Check for required arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <username> <password> <input_file>" >&2
    echo "Example: $0 myuser mypass node_ids.txt" >&2
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"
INPUT="$3"
HOST="cms.lifeway.com"
ALF_SERVICE_URL="https://${USERNAME}:${PASSWORD}@${HOST}/alfresco/service/"
DOWNLOADED_FILE_FOLDER="$HOME/Desktop/bibleTeach_VBS"

# Create download directory
mkdir -p "$DOWNLOADED_FILE_FOLDER"

# Set up log file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${DOWNLOADED_FILE_FOLDER}/failed_downloads_${TIMESTAMP}.log"

# Initialize log file
echo "Failed Downloads Log - $(date)" > "$LOG_FILE"
echo "=======================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Check if input file exists
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found" >&2
    exit 99
fi

# Function to log failed download
log_failure() {
    local node_id="$1"
    local line_number="$2"
    local error_message="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] Line $line_number - Node ID: $node_id" >> "$LOG_FILE"
    echo "Error: $error_message" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
}

# Function to sanitize filename
sanitize_filename() {
    local filename="$1"
    # Replace problematic characters with underscores
    # Keep alphanumeric, dots, hyphens, and underscores
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Function to create unique filename if duplicate exists
create_unique_filename() {
    local filename="$1"
    local directory="$2"
    local full_path="${directory}/${filename}"
    
    # If file doesn't exist, return original name
    if [ ! -e "$full_path" ]; then
        echo "$filename"
        return 0
    fi
    
    # Extract base name and extension
    local base_name="${filename%.*}"
    local extension="${filename##*.}"
    
    # If filename has no extension, treat entire name as base
    if [ "$base_name" = "$extension" ]; then
        base_name="$filename"
        extension=""
    fi
    
    # Try adding incremental numbers
    local counter=1
    while true; do
        if [ -n "$extension" ]; then
            local new_filename="${base_name}_${counter}.${extension}"
        else
            local new_filename="${base_name}_${counter}"
        fi
        
        if [ ! -e "${directory}/${new_filename}" ]; then
            echo "$new_filename"
            return 0
        fi
        
        counter=$((counter + 1))
        
        # Safety check to prevent infinite loop
        if [ $counter -gt 1000 ]; then
            echo "Error: Could not create unique filename after 1000 attempts" >&2
            return 1
        fi
    done
}

# Function to download a single file
download_file() {
    local node_id="$1"
    local line_number="$2"
    
    echo "Processing node $line_number: $node_id"
    
    # Get metadata with error handling
    local metadata_response
    metadata_response=$(curl -s --location --request GET "${ALF_SERVICE_URL}api/node/workspace/SpacesStore/${node_id}/metadata" 2>/dev/null)
    local curl_exit_code=$?
    
    if [ $curl_exit_code -ne 0 ]; then
        local error_msg="Failed to fetch metadata (curl exit code: $curl_exit_code)"
        echo "Error: $error_msg" >&2
        log_failure "$node_id" "$line_number" "$error_msg"
        return 1
    fi
    
    # Extract filename from JSON response
    local file_name
    file_name=$(echo "$metadata_response" | jq -r '.name' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        local error_msg="Failed to parse JSON response"
        echo "Error: $error_msg" >&2
        log_failure "$node_id" "$line_number" "$error_msg"
        return 1
    fi
    
    if [ "$file_name" = "null" ] || [ -z "$file_name" ]; then
        local error_msg="Could not extract filename from metadata"
        echo "Error: $error_msg" >&2
        log_failure "$node_id" "$line_number" "$error_msg"
        return 1
    fi
    
    echo "Original filename: $file_name"
    
    # Create safe filename
    local safe_file_name
    safe_file_name=$(sanitize_filename "$file_name")
    echo "Safe filename: $safe_file_name"
    
    # Create unique filename to avoid duplicates
    local unique_file_name
    unique_file_name=$(create_unique_filename "$safe_file_name" "$DOWNLOADED_FILE_FOLDER")
    
    if [ $? -ne 0 ]; then
        local error_msg="Failed to create unique filename for $safe_file_name"
        echo "Error: $error_msg" >&2
        log_failure "$node_id" "$line_number" "$error_msg"
        return 1
    fi
    
    if [ "$unique_file_name" != "$safe_file_name" ]; then
        echo "Duplicate detected, using unique filename: $unique_file_name"
    fi
    
    # Download the file
    echo "Downloading..."
    curl -s --location --request GET "${ALF_SERVICE_URL}api/node/content/workspace/SpacesStore/${node_id}" \
        --output "${DOWNLOADED_FILE_FOLDER}/${unique_file_name}"
    
    local download_exit_code=$?
    if [ $download_exit_code -eq 0 ]; then
        echo "✓ Successfully downloaded: ${unique_file_name}"
    else
        local error_msg="Download failed (curl exit code: $download_exit_code)"
        echo "✗ Error: $error_msg" >&2
        log_failure "$node_id" "$line_number" "$error_msg"
        return 1
    fi
    
    echo "---"
}

# Initialize counters
total_files=0
successful_downloads=0
failed_downloads=0

# Process each node ID from the input file
while IFS= read -r node_id; do
    # Skip empty lines and lines starting with #
    if [[ -z "$node_id" || "$node_id" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Remove leading/trailing whitespace
    node_id=$(echo "$node_id" | xargs)
    
    total_files=$((total_files + 1))
    
    if download_file "$node_id" "$total_files"; then
        successful_downloads=$((successful_downloads + 1))
    else
        failed_downloads=$((failed_downloads + 1))
    fi
done < "$INPUT"

# Finalize log file
if [ $failed_downloads -eq 0 ]; then
    echo "" >> "$LOG_FILE"
    echo "No failures occurred during this download session." >> "$LOG_FILE"
else
    echo "" >> "$LOG_FILE"
    echo "Summary: $failed_downloads out of $total_files downloads failed." >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
echo "Log completed at $(date)" >> "$LOG_FILE"

# Print summary
echo "========================================="
echo "Download Summary:"
echo "Total files processed: $total_files"
echo "Successful downloads: $successful_downloads"
echo "Failed downloads: $failed_downloads"
echo "Files saved to: $DOWNLOADED_FILE_FOLDER"

if [ $failed_downloads -gt 0 ]; then
    echo "Failed downloads logged to: $LOG_FILE"
else
    echo "No failures occurred. Empty log file created: $LOG_FILE"
fi

# Exit with appropriate code
if [ $failed_downloads -gt 0 ]; then
    exit 1
else
    exit 0
fi