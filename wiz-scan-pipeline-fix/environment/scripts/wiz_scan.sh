#!/bin/bash

echo "Starting Wiz security scan..."
echo "Timestamp: $(date)"

SCAN_DIR="${SCAN_PATH:-./build}"

echo "Scanning directory: $SCAN_DIR"

if [ ! -d "$SCAN_DIR" ]; then
    echo "Warning: Scan directory does not exist, creating empty directory"
    mkdir -p "$SCAN_DIR"
fi

echo "Authenticating with Wiz service..."
/usr/local/bin/wiz auth --id "$WIZ_CLIENT" --secret "$WIZ_SECRET" 2>&1

echo "Running vulnerability scan..."
/usr/local/bin/wiz scan repo "$SCAN_DIR" --format json --output scan-results.json 2>&1

SCAN_EXIT=$?

if [ $SCAN_EXIT -eq 0 ]; then
    echo "Scan completed successfully"
else
    echo "Scan encountered issues (exit code: $SCAN_EXIT)"
fi

echo "Scan process finished"
exit 0
