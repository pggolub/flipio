#!/bin/bash

# Calculate SHA256 for Release Archive
# Usage: ./scripts/calculate-sha256.sh path/to/Flipio-1.0.0.zip

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-zip-file>"
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/Flipio-1.0.0.zip"
    exit 1
fi

ZIP_FILE="$1"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File not found: $ZIP_FILE"
    exit 1
fi

echo "Calculating SHA256 for: $ZIP_FILE"
echo ""

SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')

echo "SHA256: $SHA256"
echo ""
echo "Update the cask formula:"
echo "  sha256 \"$SHA256\""
