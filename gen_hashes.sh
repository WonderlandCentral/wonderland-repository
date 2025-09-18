#!/bin/bash

# Exit on error
set -e

# Function to generate hash and remove filename from output
generate_hash() {
    local file=$1
    local algo=$2
    local suffix=$3

    case "$algo" in
        md5)    hash=$(md5sum "$file" | awk '{print $1}') ;;
        sha1)   hash=$(sha1sum "$file" | awk '{print $1}') ;;
        sha256) hash=$(sha256sum "$file" | awk '{print $1}') ;;
        sha512) hash=$(sha512sum "$file" | awk '{print $1}') ;;
        *) echo "Unknown algorithm: $algo" >&2; return 1 ;;
    esac

    echo "$hash" > "$file.$suffix"
}

# Find all .jar and .pom files recursively
find . -type f \( -name "*.jar" -o -name "*.pom" \) | while read -r file; do
    echo "Generating hashes for: $file"

    generate_hash "$file" md5 md5
    generate_hash "$file" sha1 sha1
    generate_hash "$file" sha256 sha256
    generate_hash "$file" sha512 sha512

    echo "Generated hashes for: $(basename "$file")"
done
