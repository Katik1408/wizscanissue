#!/bin/bash
set -e

echo "Applying security fixes for Wiz scan findings..."

# Fix 1: Update base image to patched version (fixes CRITICAL CVE)
echo "Fix 1: Updating base image to patched version..."
sed -i 's|mcr.microsoft.com/dotnet/aspnet:6.0 AS base|mcr.microsoft.com/dotnet/aspnet:6.0.28-jammy AS base|g' /app/src/SecureWebApp/Dockerfile
sed -i 's|mcr.microsoft.com/dotnet/sdk:6.0 AS build|mcr.microsoft.com/dotnet/sdk:6.0.428 AS build|g' /app/src/SecureWebApp/Dockerfile

# Fix 2: Remove hardcoded secrets from appsettings.json (fixes HIGH secrets)
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

# Fix 3: Add USER directive to Dockerfile (fixes MEDIUM non-root)
echo "Fix 3: Adding non-root user directive..."
sed -i 's|ENTRYPOINT \["dotnet", "SecureWebApp.dll"\]|USER app\nENTRYPOINT ["dotnet", "SecureWebApp.dll"]|g' /app/src/SecureWebApp/Dockerfile

# Fix 4: Update vulnerable System.Text.Json package (fixes HIGH CVE)
# Also update Azure.Identity to compatible version to avoid transitive dependency conflict
echo "Fix 4: Updating vulnerable NuGet packages..."
cat > /app/src/SecureWebApp/SecureWebApp.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <!-- Fixed version - CVE-2024-30105 patched in 6.0.10 -->
    <PackageReference Include="System.Text.Json" Version="6.0.10" />
    
    <!-- Updated for compatibility with System.Text.Json 6.0.10 -->
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="6.0.0" />
    
    <!-- Red herring - deprecated but not a security issue -->
    <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
    
    <!-- Updated Azure SDK compatible with System.Text.Json 6.0.10 -->
    <PackageReference Include="Azure.Identity" Version="1.10.4" />
  </ItemGroup>

</Project>
EOF

echo "All security fixes applied successfully!"
echo "Summary of changes:"
echo "  1. Updated base image from aspnet:6.0 to aspnet:6.0.28-jammy"
echo "  2. Removed hardcoded secrets from appsettings.json"
echo "  3. Added USER app directive for non-root execution"
echo "  4. Updated System.Text.Json to 6.0.10 and Azure.Identity to 1.10.4"
