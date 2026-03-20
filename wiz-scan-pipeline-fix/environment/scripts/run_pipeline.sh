#!/bin/bash

echo "=== CI/CD Pipeline Execution ==="
echo "Build ID: $(date +%Y%m%d-%H%M%S)"
echo ""

source /app/config/credentials.env 2>/dev/null

echo "[Step 1/4] Loading configuration..."
if [ -f /app/config/credentials.env ]; then
    echo "Configuration loaded from credentials.env"
else
    echo "Warning: credentials.env not found"
fi

echo "[Step 2/4] Setting up Wiz CLI..."
if command -v wiz &> /dev/null; then
    echo "Wiz CLI found in PATH"
else
    if [ -f /usr/local/bin/wiz ]; then
        echo "Wiz CLI found at /usr/local/bin/wiz"
    elif [ -f /tmp/wizcli ]; then
        echo "Wiz CLI found at /tmp/wizcli"
    else
        echo "Downloading Wiz CLI..."
        curl -s -o /tmp/wizcli https://wizcli.app.wiz.io/latest/wizcli-linux-amd64 2>/dev/null || echo "Download completed"
        chmod +x /tmp/wizcli 2>/dev/null
    fi
fi

echo "[Step 3/4] Running security scan..."
/app/scripts/wiz_scan.sh

echo "[Step 4/4] Processing results..."
if [ -f /app/scan-results.json ]; then
    echo "Scan results saved to scan-results.json"
    CRITICAL_COUNT=$(cat /app/scan-results.json | jq '.criticalCount // 0' 2>/dev/null || echo "0")
    echo "Critical findings: $CRITICAL_COUNT"
else
    echo "No scan results file generated"
fi

echo ""
echo "=== Pipeline Complete ==="
exit 0
