# Security Scan Pipeline Debug

## Context

Your organization uses Wiz for container security scanning as part of the CI/CD pipeline. Recently, the security scan pipeline has been experiencing issues - scans either fail silently, produce incomplete results, or report success when they shouldn't.

## Problem

The DevOps team has reported that the security scan pipeline is not functioning correctly. Deployments are going through without proper security validation, which is a compliance violation. The pipeline appears to complete successfully, but security findings are not being captured properly.

## Your Task

Debug and fix the security scan pipeline so that:
1. The scan actually executes against the correct target
2. Authentication with the Wiz service works properly
3. Scan results are captured and reported accurately
4. The pipeline fails appropriately when security issues are found

## Available Files

- `pipeline.yml` - CI/CD pipeline configuration
- `scripts/wiz_scan.sh` - Security scan execution script
- `config/` - Configuration files
- `logs/` - Pipeline execution logs
- `src/` - Application source code to be scanned

## Success Criteria

The pipeline should:
- Execute the Wiz scan successfully
- Scan the correct application directory
- Report actual security findings
- Fail the pipeline if critical issues are found
