#!/bin/zsh

# URL Checker Script
# Usage: ./check_urls.sh <input_file> [output_log]

# Check if input file is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input_file> [output_log]"
    echo "Example: $0 urls.txt check_results.log"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_LOG="${2:-url_check_results.log}"

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

# Initialize log file with header
echo "URL Check Results - $(date)" > "$OUTPUT_LOG"
echo "=================================" >> "$OUTPUT_LOG"
echo "" >> "$OUTPUT_LOG"

# Counters
total_urls=0
successful_urls=0
failed_urls=0

echo "Starting URL validation..."
echo "Input file: $INPUT_FILE"
echo "Log file: $OUTPUT_LOG"
echo ""

# Debug: Show first few lines of input file
echo "Debug: First 3 lines of input file:"
head -3 "$INPUT_FILE"
echo ""

# Read URLs from file and process each one
while IFS= read -r url || [[ -n "$url" ]]; do
    # Debug: Show what we're reading
    echo "Debug: Read line: '$url'"
    
    # Skip empty lines and lines that don't start with http
    if [[ -z "$url" || ! "$url" =~ ^https?:// ]]; then
        echo "Debug: Skipping line (empty or doesn't start with http)"
        continue
    fi
    
    ((total_urls++))
    
    echo -n "Checking URL $total_urls: "
    
    # Use curl to check if URL resolves successfully
    # -s: silent mode
    # -f: fail silently on HTTP errors
    # -L: follow redirects
    # --max-time: timeout after specified seconds
    # -I: head request only (faster)
    if curl -s -f -L --max-time 10 -I "$url" > /dev/null 2>&1; then
        result="SUCCESS"
        ((successful_urls++))
        echo "✓ SUCCESS"
    else
        result="FAILED"
        ((failed_urls++))
        echo "✗ FAILED"
    fi
    
    # Log the result with timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $result: $url" >> "$OUTPUT_LOG"
    
done < "$INPUT_FILE"

# Add summary to log file
echo "" >> "$OUTPUT_LOG"
echo "=================================" >> "$OUTPUT_LOG"
echo "SUMMARY:" >> "$OUTPUT_LOG"
echo "Total URLs checked: $total_urls" >> "$OUTPUT_LOG"
echo "Successful: $successful_urls" >> "$OUTPUT_LOG"
echo "Failed: $failed_urls" >> "$OUTPUT_LOG"
echo "Success rate: $(( total_urls > 0 ? (successful_urls * 100) / total_urls : 0 ))%" >> "$OUTPUT_LOG"

# Display summary to console
echo ""
echo "================================="
echo "URL Check Complete!"
echo "Total URLs checked: $total_urls"
echo "Successful: $successful_urls"
echo "Failed: $failed_urls"
echo "Success rate: $(( total_urls > 0 ? (successful_urls * 100) / total_urls : 0 ))%"
echo ""
echo "Detailed results saved to: $OUTPUT_LOG"