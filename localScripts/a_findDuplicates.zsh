#!/bin/zsh
# Set directory (default to current)
dir="${1:-.}"
# Check if directory exists
[[ ! -d "$dir" ]] && { echo "Directory '$dir' not found"; exit 1; }
# Find duplicates using associative array
typeset -A basenames
for file in "$dir"/*; do
    [[ -f "$file" ]] || continue
    name="${file:t:r}"  # filename without path and extension
    [[ -n "$name" ]] || continue
    # Convert to lowercase for case-insensitive comparison
    name_lower="${name:l}"
    basenames[$name_lower]+="$file "
done
# Print duplicates in alphabetical order
found=false
for base in "${(@ko)basenames}"; do
    files=(${=basenames[$base]})
    if (( ${#files} > 1 )); then
        found=true
        echo "\nDuplicate: '$base'"
        printf "  %s\n" "${files[@]:t}"
    fi
done
$found || echo "No duplicates found"