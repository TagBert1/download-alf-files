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
DOWNLOADED_FILE_FOLDER="$HOME/Desktop/comissioned-art"

# Create download directory
mkdir -p "$DOWNLOADED_FILE_FOLDER"

# Check if input file exists
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' not found" >&2
    exit 99
fi

# Function to sanitize filename
sanitize_filename() {
    local filename="$1"
    # Replace problematic characters with underscores
    # Keep alphanumeric, dots, hyphens, and underscores
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g'
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
        echo "Error: Failed to fetch metadata for node $node_id (exit code: $curl_exit_code)" >&2
        return 1
    fi
    
    # Extract filename from JSON response
    local file_name
    file_name=$(echo "$metadata_response" | jq -r '.name' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to parse JSON response for node $node_id" >&2
        return 1
    fi
    
    if [ "$file_name" = "null" ] || [ -z "$file_name" ]; then
        echo "Error: Could not extract filename from metadata for node $node_id" >&2
        return 1
    fi
    
    echo "Original filename: $file_name"
    
    # Create safe filename
    local safe_file_name
    safe_file_name=$(sanitize_filename "$file_name")
    echo "Safe filename: $safe_file_name"
    
    # Download the file
    echo "Downloading..."
    curl -s --location --request GET "${ALF_SERVICE_URL}api/node/content/workspace/SpacesStore/${node_id}" \
        --output "${DOWNLOADED_FILE_FOLDER}/${safe_file_name}"
    
    local download_exit_code=$?
    if [ $download_exit_code -eq 0 ]; then
        echo "✓ Successfully downloaded: ${safe_file_name}"
    else
        echo "✗ Error: Download failed for node $node_id (exit code: $download_exit_code)" >&2
        return 1
        
        echo "---"
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

# Print summary
echo "========================================="
echo "Download Summary:"
echo "Total files processed: $total_files"
echo "Successful downloads: $successful_downloads"
echo "Failed downloads: $failed_downloads"
echo "Files saved to: $DOWNLOADED_FILE_FOLDER"

# Exit with appropriate code
if [ $failed_downloads -gt 0 ]; then
    exit 1
else
    exit 0
fi