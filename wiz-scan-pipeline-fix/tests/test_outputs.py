import pytest
import json
import re
import os


class TestSecurityFixes:
    """Test suite to verify all security scan findings have been resolved."""

    @pytest.fixture
    def dockerfile_content(self):
        """Read the Dockerfile content."""
        with open('/app/src/SecureWebApp/Dockerfile', 'r') as f:
            return f.read()

    @pytest.fixture
    def appsettings_content(self):
        """Read the appsettings.json content."""
        with open('/app/src/SecureWebApp/appsettings.json', 'r') as f:
            return f.read()

    @pytest.fixture
    def appsettings_json(self):
        """Parse appsettings.json as JSON."""
        with open('/app/src/SecureWebApp/appsettings.json', 'r') as f:
            return json.load(f)

    @pytest.fixture
    def csproj_content(self):
        """Read the .csproj file content."""
        with open('/app/src/SecureWebApp/SecureWebApp.csproj', 'r') as f:
            return f.read()

    # ==================== CRITICAL: Base Image CVE ====================

    def test_base_image_not_vulnerable_tag(self, dockerfile_content):
        """Test that the base image is not using the vulnerable 6.0 tag."""
        vulnerable_patterns = [
            r'FROM\s+mcr\.microsoft\.com/dotnet/aspnet:6\.0\s+AS',
            r'FROM\s+mcr\.microsoft\.com/dotnet/aspnet:6\.0\s*$',
            r'FROM\s+mcr\.microsoft\.com/dotnet/aspnet:6\.0\n',
        ]
        for pattern in vulnerable_patterns:
            match = re.search(pattern, dockerfile_content, re.MULTILINE)
            assert match is None, \
                f"Base image still using vulnerable tag 'aspnet:6.0'. Must use patched version like '6.0.28-jammy' or '8.0'"

    def test_base_image_uses_patched_version(self, dockerfile_content):
        """Test that the base image uses a patched version."""
        patched_patterns = [
            r'mcr\.microsoft\.com/dotnet/aspnet:6\.0\.\d+-',  # e.g., 6.0.28-jammy
            r'mcr\.microsoft\.com/dotnet/aspnet:6\.0\.\d+\s',  # e.g., 6.0.28
            r'mcr\.microsoft\.com/dotnet/aspnet:8\.0',  # .NET 8
        ]
        found_patched = any(re.search(p, dockerfile_content) for p in patched_patterns)
        assert found_patched, \
            "Base image must use a patched version (e.g., 6.0.28-jammy, 6.0.28, or 8.0)"

    # ==================== HIGH: Hardcoded Secrets ====================

    def test_no_hardcoded_database_password(self, appsettings_content):
        """Test that database connection string does not contain hardcoded password."""
        password_patterns = [
            r'Password\s*=\s*[^;"\s]{4,}',  # Password with actual value
            r'Pwd\s*=\s*[^;"\s]{4,}',
            r'Pr0d_S3cr3t',
            r'P@ssw0rd',
        ]
        for pattern in password_patterns:
            match = re.search(pattern, appsettings_content, re.IGNORECASE)
            assert match is None, \
                f"Hardcoded database password detected. Remove secrets from appsettings.json"

    def test_no_hardcoded_azure_client_secret(self, appsettings_content):
        """Test that Azure AD client secret is not hardcoded."""
        secret_patterns = [
            r'"ClientSecret"\s*:\s*"[^"]{10,}"',  # Non-empty client secret
            r'super_secret_client',
            r'credential_value',
        ]
        for pattern in secret_patterns:
            match = re.search(pattern, appsettings_content, re.IGNORECASE)
            assert match is None, \
                f"Hardcoded Azure AD client secret detected. Remove from appsettings.json"

    def test_no_hardcoded_redis_password(self, appsettings_content):
        """Test that Redis password is not hardcoded."""
        redis_patterns = [
            r'password\s*=\s*R3d1s',
            r'Pr0d_P@ss',
        ]
        for pattern in redis_patterns:
            match = re.search(pattern, appsettings_content, re.IGNORECASE)
            assert match is None, \
                f"Hardcoded Redis password detected. Remove from appsettings.json"

    def test_no_hardcoded_api_keys(self, appsettings_content):
        """Test that API keys are not hardcoded."""
        api_key_patterns = [
            r'sk-live-',
            r'"ThirdPartyService"\s*:\s*"[^"]{10,}"',
        ]
        for pattern in api_key_patterns:
            match = re.search(pattern, appsettings_content, re.IGNORECASE)
            assert match is None, \
                f"Hardcoded API key detected. Remove from appsettings.json"

    def test_connection_string_empty_or_placeholder(self, appsettings_json):
        """Test that connection strings are empty or use placeholders."""
        conn_string = appsettings_json.get('ConnectionStrings', {}).get('DefaultConnection', '')
        # Should be empty, placeholder, or environment variable reference
        is_safe = (
            conn_string == '' or
            conn_string.startswith('${') or
            'Password=' not in conn_string or
            'Password=;' in conn_string or
            'Password=""' in conn_string
        )
        assert is_safe, \
            f"Connection string must not contain actual credentials"

    # ==================== HIGH: Vulnerable NuGet Package ====================

    def test_system_text_json_version_patched(self, csproj_content):
        """Test that System.Text.Json is updated to patched version."""
        vulnerable_pattern = r'System\.Text\.Json.*Version\s*=\s*"6\.0\.[0-9]"'
        match = re.search(vulnerable_pattern, csproj_content)
        assert match is None, \
            "System.Text.Json 6.0.0-6.0.9 is vulnerable to CVE-2024-30105. Update to 6.0.10+"

    def test_system_text_json_minimum_version(self, csproj_content):
        """Test that System.Text.Json meets minimum safe version."""
        version_match = re.search(
            r'System\.Text\.Json.*Version\s*=\s*"(\d+)\.(\d+)\.(\d+)"',
            csproj_content
        )
        if version_match:
            major, minor, patch = map(int, version_match.groups())
            if major == 6 and minor == 0:
                assert patch >= 10, \
                    f"System.Text.Json {major}.{minor}.{patch} is vulnerable. Need 6.0.10+"
            elif major == 8 and minor == 0:
                assert patch >= 4, \
                    f"System.Text.Json {major}.{minor}.{patch} is vulnerable. Need 8.0.4+"

    # ==================== MEDIUM: Non-Root Container ====================

    def test_dockerfile_has_user_directive(self, dockerfile_content):
        """Test that Dockerfile includes USER directive for non-root execution."""
        user_pattern = r'^\s*USER\s+(?!root)'
        match = re.search(user_pattern, dockerfile_content, re.MULTILINE)
        assert match is not None, \
            "Dockerfile must include 'USER app' or similar non-root USER directive"

    def test_user_directive_not_root(self, dockerfile_content):
        """Test that USER directive does not specify root."""
        root_user_pattern = r'^\s*USER\s+root\s*$'
        match = re.search(root_user_pattern, dockerfile_content, re.MULTILINE)
        assert match is None, \
            "USER directive must not be 'root'. Use 'app' or another non-root user"

    def test_user_directive_before_entrypoint(self, dockerfile_content):
        """Test that USER directive appears before ENTRYPOINT."""
        user_pos = dockerfile_content.find('USER ')
        entrypoint_pos = dockerfile_content.find('ENTRYPOINT')
        
        if user_pos == -1:
            pytest.fail("USER directive not found in Dockerfile")
        
        if entrypoint_pos != -1:
            assert user_pos < entrypoint_pos, \
                "USER directive should appear before ENTRYPOINT"

    # ==================== Functional Tests ====================

    def test_dockerfile_syntax_valid(self, dockerfile_content):
        """Test that Dockerfile has valid basic structure."""
        required_directives = ['FROM', 'WORKDIR', 'COPY', 'ENTRYPOINT']
        for directive in required_directives:
            assert directive in dockerfile_content, \
                f"Dockerfile missing required directive: {directive}"

    def test_appsettings_valid_json(self):
        """Test that appsettings.json is valid JSON."""
        try:
            with open('/app/src/SecureWebApp/appsettings.json', 'r') as f:
                json.load(f)
        except json.JSONDecodeError as e:
            pytest.fail(f"appsettings.json is not valid JSON: {e}")

    def test_csproj_valid_xml(self, csproj_content):
        """Test that .csproj file has valid XML structure."""
        assert '<Project' in csproj_content, "Missing Project root element"
        assert '</Project>' in csproj_content, "Missing closing Project tag"
        assert '<ItemGroup>' in csproj_content, "Missing ItemGroup element"

    def test_csproj_has_required_packages(self, csproj_content):
        """Test that required packages are still present."""
        required_packages = [
            'System.Text.Json',
            'Microsoft.Extensions.Configuration.Json',
        ]
        for package in required_packages:
            assert package in csproj_content, \
                f"Required package {package} is missing from .csproj"


class TestNoRegressions:
    """Ensure fixes don't break the application."""

    def test_dockerfile_still_builds_dotnet_app(self):
        """Test that Dockerfile still references .NET build steps."""
        with open('/app/src/SecureWebApp/Dockerfile', 'r') as f:
            content = f.read()
        
        assert 'dotnet restore' in content or 'dotnet build' in content or 'dotnet publish' in content, \
            "Dockerfile must still contain .NET build commands"

    def test_appsettings_has_logging_config(self):
        """Test that logging configuration is preserved."""
        with open('/app/src/SecureWebApp/appsettings.json', 'r') as f:
            config = json.load(f)
        
        assert 'Logging' in config, "Logging configuration must be preserved"

    def test_appsettings_has_connection_string_key(self):
        """Test that ConnectionStrings key exists (even if empty)."""
        with open('/app/src/SecureWebApp/appsettings.json', 'r') as f:
            config = json.load(f)
        
        assert 'ConnectionStrings' in config, \
            "ConnectionStrings section must exist (values can be empty for runtime injection)"
