# Fix Deployment Pipeline Blocked by Security Scan

## Background

You are a DevOps engineer at a company that uses Wiz for container security scanning. The CI/CD pipeline for a .NET web application has been blocked because the security scan detected critical and high-severity vulnerabilities.

The deployment has been halted and the team cannot release the latest features until all blocking security findings are resolved.

## Your Task

The application is located in `/app/`. The security scan report is available at `/app/scan-report.json`.

Your goal is to fix all **CRITICAL** and **HIGH** severity findings so the deployment can proceed. The scan must pass with no CRITICAL or HIGH severity issues remaining.

**Important Notes:**
- Review the scan report carefully to understand what needs to be fixed
- The application must still build and run correctly after your fixes
- Do not modify the test files or scan verification logic
- Some log files in `/app/logs/` may contain useful debugging information
- Focus on the security issues, not warnings about image size or deprecated APIs

## Files You May Need to Modify

- `/app/src/SecureWebApp/Dockerfile`
- `/app/src/SecureWebApp/SecureWebApp.csproj`
- `/app/src/SecureWebApp/appsettings.json`
- Other files as needed based on your analysis

## Success Criteria

1. All CRITICAL severity findings are resolved
2. All HIGH severity findings are resolved  
3. The Docker image builds successfully
4. The application starts without errors

## Hints

- Read the scan report thoroughly before making changes
- Security fixes sometimes require updating multiple related components
- Be careful with dependency versions - some packages have interdependencies
- Removing secrets from config files may require providing alternative configuration methods
