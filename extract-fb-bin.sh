#!/bin/bash

# Check if the docker image
if [ -z "$1" ]; then
    echo "Usage: $0 <docker-image>"
    exit 1
fi

# Define variables
OUTER_TAR="$1"
TMP_DIR=$(mktemp -d)

# Extract the docker image into the temporary directory
docker save "$1" | tar -x -C "$TMP_DIR" -f -

# Find the inner tar file that contains a file starting with 'fluent-bit'
INNER_TAR=""
while IFS= read -r -d '' file; do
    if tar -tf "$file" &> /dev/null && tar -tf "$file" | grep -q '^fluent-bit'; then
        INNER_TAR="$file"
        break
    fi
done < <(find "$TMP_DIR" -type f -print0)

# Check if the inner tar file was found
if [ -z "$INNER_TAR" ]; then
    echo "Inner tar file containing a file that starts with 'fluent-bit' not found."
    exit 1
fi

# Extract the inner tar file to /tmp/fb-bins
tar -xf "$INNER_TAR" -C /tmp/fb-bins

# Output the location of the extracted files
echo "Extracted inner tar file to: /tmp/fb-bins"

# Optionally, clean up the temporary directory
# Uncomment the next line if you want to remove the temporary directory after extraction
rm -rf "$TMP_DIR"

exit 0
