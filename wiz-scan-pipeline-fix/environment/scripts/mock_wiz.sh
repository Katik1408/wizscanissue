#!/bin/bash

CMD="$1"
shift

case "$CMD" in
    "auth")
        CLIENT_ID=""
        CLIENT_SECRET=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --id) CLIENT_ID="$2"; shift 2 ;;
                --secret) CLIENT_SECRET="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        
        if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
            echo "Error: Missing required authentication parameters"
            echo "Usage: wiz auth --id <client_id> --secret <client_secret>"
            exit 1
        fi
        
        if [ "$CLIENT_ID" = "wiz-prod-client-id" ] && [ "$CLIENT_SECRET" = "wiz-prod-secret-key" ]; then
            echo "Authentication successful"
            echo '{"authenticated": true, "expires": "2024-03-16T00:00:00Z"}' > /tmp/wiz_auth_token
            exit 0
        else
            echo "Error: Authentication failed - invalid credentials"
            exit 1
        fi
        ;;
    
    "dir")
        SUBCMD="$1"
        shift
        if [ "$SUBCMD" = "scan" ]; then
            TARGET_DIR=""
            OUTPUT_FILE=""
            FORMAT="text"
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
                    --format|-f) FORMAT="$2"; shift 2 ;;
                    *) 
                        if [ -z "$TARGET_DIR" ]; then
                            TARGET_DIR="$1"
                        fi
                        shift 
                        ;;
                esac
            done
            
            if [ ! -f /tmp/wiz_auth_token ]; then
                echo "Error: Not authenticated. Run 'wiz auth' first."
                exit 1
            fi
            
            if [ -z "$TARGET_DIR" ]; then
                echo "Error: No target directory specified"
                exit 1
            fi
            
            if [ ! -d "$TARGET_DIR" ]; then
                echo "Error: Target directory '$TARGET_DIR' does not exist"
                exit 1
            fi
            
            FILE_COUNT=$(find "$TARGET_DIR" -type f 2>/dev/null | wc -l)
            if [ "$FILE_COUNT" -eq 0 ]; then
                echo "Warning: Target directory is empty"
                echo '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}, "scanned_files": 0}' > "${OUTPUT_FILE:-scan-results.json}"
                exit 0
            fi
            
            echo "Scanning directory: $TARGET_DIR"
            echo "Found $FILE_COUNT files to scan"
            
            CRITICAL=0
            HIGH=0
            
            if [ -f "$TARGET_DIR/package.json" ]; then
                if grep -q '"lodash": "4.17.20"' "$TARGET_DIR/package.json" 2>/dev/null; then
                    CRITICAL=$((CRITICAL + 1))
                fi
                if grep -q '"axios": "0.21.1"' "$TARGET_DIR/package.json" 2>/dev/null; then
                    HIGH=$((HIGH + 1))
                fi
                if grep -q '"jsonwebtoken": "8.5.1"' "$TARGET_DIR/package.json" 2>/dev/null; then
                    HIGH=$((HIGH + 1))
                fi
            fi
            
            RESULT='{
  "scan_id": "scan-'$(date +%s)'",
  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "target": "'$TARGET_DIR'",
  "findings": [
    {"id": "CVE-2021-23337", "severity": "CRITICAL", "package": "lodash", "version": "4.17.20", "fixed_in": "4.17.21"},
    {"id": "CVE-2021-3749", "severity": "HIGH", "package": "axios", "version": "0.21.1", "fixed_in": "0.21.2"},
    {"id": "CVE-2022-23529", "severity": "HIGH", "package": "jsonwebtoken", "version": "8.5.1", "fixed_in": "9.0.0"}
  ],
  "summary": {
    "critical": '$CRITICAL',
    "high": '$HIGH',
    "medium": 0,
    "low": 0,
    "total": '$((CRITICAL + HIGH))'
  },
  "scanned_files": '$FILE_COUNT',
  "status": "completed"
}'
            
            if [ -n "$OUTPUT_FILE" ]; then
                echo "$RESULT" > "$OUTPUT_FILE"
                echo "Results written to $OUTPUT_FILE"
            else
                echo "$RESULT"
            fi
            
            if [ $CRITICAL -gt 0 ]; then
                echo "CRITICAL vulnerabilities found!"
                exit 2
            elif [ $HIGH -gt 0 ]; then
                echo "HIGH vulnerabilities found!"
                exit 1
            fi
            exit 0
        else
            echo "Error: Unknown subcommand '$SUBCMD'. Available: scan"
            exit 1
        fi
        ;;
    
    "scan")
        echo "Error: Invalid command 'wiz scan'. Did you mean 'wiz dir scan'?"
        echo "Usage: wiz dir scan <directory> [options]"
        exit 1
        ;;
    
    "version")
        echo "wiz-cli version 1.2.3"
        exit 0
        ;;
    
    "help"|"--help"|"-h")
        echo "Wiz CLI - Security Scanner"
        echo ""
        echo "Commands:"
        echo "  auth      Authenticate with Wiz service"
        echo "  dir scan  Scan a directory for vulnerabilities"
        echo "  version   Show version information"
        echo ""
        echo "Examples:"
        echo "  wiz auth --id <client_id> --secret <client_secret>"
        echo "  wiz dir scan ./src --output results.json --format json"
        exit 0
        ;;
    
    *)
        echo "Error: Unknown command '$CMD'"
        echo "Run 'wiz help' for usage information"
        exit 1
        ;;
esac
