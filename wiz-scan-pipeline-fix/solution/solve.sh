#!/bin/bash
set -e

echo "=== Applying security fixes for Wiz scan findings ==="

# Fix 1: Update base image to patched version (fixes CRITICAL OpenSSL CVE)
# The base image mcr.microsoft.com/dotnet/aspnet:6.0 contains vulnerable OpenSSL
# Must use a specific patched tag like 6.0.28-jammy which includes OpenSSL fixes
echo "Fix 1: Updating base image to patched version..."
sed -i 's|mcr.microsoft.com/dotnet/aspnet:6.0 AS base|mcr.microsoft.com/dotnet/aspnet:6.0.28-jammy AS base|g' /app/src/SecureWebApp/Dockerfile
sed -i 's|mcr.microsoft.com/dotnet/sdk:6.0 AS build|mcr.microsoft.com/dotnet/sdk:6.0.428 AS build|g' /app/src/SecureWebApp/Dockerfile

# Fix 2: Remove hardcoded secrets from appsettings.json (fixes HIGH secrets)
# Secrets should be injected via environment variables at runtime
echo "Fix 2: Removing hardcoded secrets from configuration..."
cat > /app/src/SecureWebApp/appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": ""
  },
  "AzureAd": {
    "TenantId": "",
    "ClientId": "",
    "ClientSecret": ""
  },
  "Redis": {
    "ConnectionString": ""
  },
  "ApiKeys": {
    "ThirdPartyService": ""
  }
}
EOF

# Fix 3: Add USER directive to Dockerfile (fixes MEDIUM privilege escalation)
# .NET base images include a pre-created 'app' user for non-root execution
echo "Fix 3: Adding non-root user directive..."
sed -i 's|ENTRYPOINT \["dotnet", "SecureWebApp.dll"\]|USER app\nENTRYPOINT ["dotnet", "SecureWebApp.dll"]|g' /app/src/SecureWebApp/Dockerfile

# Fix 4: Update vulnerable packages (fixes CRITICAL/HIGH CVEs)
# System.Text.Json 6.0.0 has CVE-2024-30105 (memory corruption) - need 6.0.10+
# Azure.Identity 1.6.0 has CVE-2024-35255 (auth bypass) - need 1.10.4+
# Microsoft.Data.SqlClient 5.1.0 has CVE-2024-21319 (DoS) - need 5.1.5+
# IMPORTANT: These packages have transitive dependencies on each other
# Azure.Identity depends on System.Text.Json, so versions must be compatible
echo "Fix 4: Updating vulnerable NuGet packages..."
cat > /app/src/SecureWebApp/SecureWebApp.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="System.Text.Json" Version="6.0.10" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="6.0.0" />
    <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
    <PackageReference Include="Azure.Identity" Version="1.10.4" />
    <PackageReference Include="Microsoft.Data.SqlClient" Version="5.1.5" />
  </ItemGroup>

</Project>
EOF

echo "=== All security fixes applied successfully ==="
echo "Summary of changes:"
echo "  1. Updated base image from aspnet:6.0 to aspnet:6.0.28-jammy (fixes OpenSSL CVE)"
echo "  2. Removed hardcoded secrets from appsettings.json"
echo "  3. Added USER app directive for non-root execution"
echo "  4. Updated System.Text.Json 6.0.0 -> 6.0.10 (fixes CVE-2024-30105)"
echo "  5. Updated Azure.Identity 1.6.0 -> 1.10.4 (fixes CVE-2024-35255)"
echo "  6. Updated Microsoft.Data.SqlClient 5.1.0 -> 5.1.5 (fixes CVE-2024-21319)"
