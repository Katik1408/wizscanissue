# Vulnerable base image - uses outdated .NET 6.0 with known CVEs
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["SecureWebApp.csproj", "SecureWebApp/"]
RUN dotnet restore "SecureWebApp/SecureWebApp.csproj"
COPY . SecureWebApp/
WORKDIR "/src/SecureWebApp"
RUN dotnet build "SecureWebApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "SecureWebApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Copy configuration with hardcoded secrets (security issue)
COPY appsettings.json .

# No USER directive - runs as root (security issue)
ENTRYPOINT ["dotnet", "SecureWebApp.dll"]
