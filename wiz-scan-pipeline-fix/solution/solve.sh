#!/bin/bash
set -e

echo "=== Fixing Wiz Security Scan Pipeline ==="

# Fix 1: Correct environment variable names in credentials.env
# Bug: Uses WIZ_CLIENT instead of WIZ_CLIENT_ID
echo "Fix 1: Correcting environment variable names..."
cat > /app/config/credentials.env << 'EOF'
WIZ_CLIENT_ID=wiz-prod-client-id
WIZ_CLIENT_SECRET=wiz-prod-secret-key
SCAN_PATH=./src/app
WIZ_ENV=production
EOF

# Fix 2: Install Wiz CLI to correct PATH location
# Bug: CLI downloaded to /tmp/wizcli but scripts look for /usr/local/bin/wiz
echo "Fix 2: Setting up Wiz CLI in correct PATH..."
cp /app/scripts/mock_wiz.sh /usr/local/bin/wiz
chmod +x /usr/local/bin/wiz

# Fix 3: Fix the scan command in wiz_scan.sh
# Bug: Uses "wiz scan repo" but correct command is "wiz dir scan"
echo "Fix 3: Fixing scan command syntax..."
cat > /app/scripts/wiz_scan.sh << 'SCRIPT'
#!/bin/bash

echo "Starting Wiz security scan..."
echo "Timestamp: $(date)"

source /app/config/credentials.env

SCAN_DIR="${SCAN_PATH:-./src/app}"

echo "Scanning directory: $SCAN_DIR"

if [ ! -d "$SCAN_DIR" ]; then
    echo "Error: Scan directory does not exist: $SCAN_DIR"
    exit 1
fi

echo "Authenticating with Wiz service..."
wiz auth --id "$WIZ_CLIENT_ID" --secret "$WIZ_CLIENT_SECRET"
AUTH_EXIT=$?

if [ $AUTH_EXIT -ne 0 ]; then
    echo "Error: Authentication failed"
    exit 1
fi

echo "Running vulnerability scan..."
wiz dir scan "$SCAN_DIR" --output /app/scan-results.json --format json

SCAN_EXIT=$?

if [ $SCAN_EXIT -eq 2 ]; then
    echo "CRITICAL vulnerabilities found - failing pipeline"
    exit 1
elif [ $SCAN_EXIT -eq 1 ]; then
    echo "HIGH vulnerabilities found - failing pipeline"
    exit 1
elif [ $SCAN_EXIT -ne 0 ]; then
    echo "Scan failed with exit code: $SCAN_EXIT"
    exit 1
fi

echo "Scan completed successfully - no blocking issues found"
exit 0
SCRIPT
chmod +x /app/scripts/wiz_scan.sh

# Fix 4: Remove false success condition from pipeline
# Bug: Pipeline uses "|| true" which masks failures
echo "Fix 4: Fixing pipeline to properly propagate errors..."
cat > /app/pipeline.yml << 'EOF'
name: Security Scan Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  WIZ_CLIENT_ID: ${{ secrets.WIZ_CLIENT_ID }}
  WIZ_CLIENT_SECRET: ${{ secrets.WIZ_CLIENT_SECRET }}
  SCAN_PATH: "./src/app"

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Wiz CLI
        run: |
          curl -o /usr/local/bin/wiz https://wizcli.app.wiz.io/latest/wizcli-linux-amd64
          chmod +x /usr/local/bin/wiz

      - name: Authenticate with Wiz
        run: |
          wiz auth --id $WIZ_CLIENT_ID --secret $WIZ_CLIENT_SECRET

      - name: Run Security Scan
        run: |
          ./scripts/wiz_scan.sh

      - name: Upload Results
        if: always()
        run: |
          echo "Scan completed"
          cat scan-results.json
EOF

# Fix 5: Correct scan target path
# Bug: SCAN_PATH points to ./build (empty) instead of ./src/app
echo "Fix 5: Scan path already corrected in credentials.env"

# Fix run_pipeline.sh to use correct variables
echo "Fixing run_pipeline.sh..."
cat > /app/scripts/run_pipeline.sh << 'SCRIPT'
#!/bin/bash

echo "=== CI/CD Pipeline Execution ==="
echo "Build ID: $(date +%Y%m%d-%H%M%S)"
echo ""

source /app/config/credentials.env

echo "[Step 1/4] Loading configuration..."
echo "WIZ_CLIENT_ID: ${WIZ_CLIENT_ID:0:10}..."
echo "SCAN_PATH: $SCAN_PATH"

echo "[Step 2/4] Setting up Wiz CLI..."
if command -v wiz &> /dev/null; then
    echo "Wiz CLI found in PATH"
    wiz version
else
    echo "Error: Wiz CLI not found"
    exit 1
fi

echo "[Step 3/4] Running security scan..."
/app/scripts/wiz_scan.sh
SCAN_RESULT=$?

if [ $SCAN_RESULT -ne 0 ]; then
    echo "Security scan failed!"
    exit 1
fi

echo "[Step 4/4] Processing results..."
if [ -f /app/scan-results.json ]; then
    echo "Scan results:"
    cat /app/scan-results.json | head -20
    
    CRITICAL_COUNT=$(cat /app/scan-results.json | grep -o '"critical": [0-9]*' | grep -o '[0-9]*' || echo "0")
    HIGH_COUNT=$(cat /app/scan-results.json | grep -o '"high": [0-9]*' | grep -o '[0-9]*' || echo "0")
    
    echo ""
    echo "Summary: Critical=$CRITICAL_COUNT, High=$HIGH_COUNT"
    
    if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$HIGH_COUNT" -gt 0 ]; then
        echo "Pipeline FAILED: Security issues found"
        exit 1
    fi
else
    echo "Error: No scan results file generated"
    exit 1
fi

echo ""
echo "=== Pipeline Complete ==="
exit 0
SCRIPT
chmod +x /app/scripts/run_pipeline.sh

echo ""
echo "=== All fixes applied ==="
echo "Summary:"
echo "  1. Fixed env var names: WIZ_CLIENT -> WIZ_CLIENT_ID, WIZ_SECRET -> WIZ_CLIENT_SECRET"
echo "  2. Installed Wiz CLI to /usr/local/bin/wiz (was only in /tmp/wizcli)"
echo "  3. Fixed scan command: 'wiz scan repo' -> 'wiz dir scan'"
echo "  4. Removed '|| true' false success conditions from pipeline"
echo "  5. Fixed scan path: ./build -> ./src/app"
