import pytest
import subprocess
import json
import os
import re


class TestEnvironmentVariables:
    """Test that environment variables are correctly configured."""

    def test_credentials_file_exists(self):
        """Test that credentials.env file exists."""
        assert os.path.exists('/app/config/credentials.env'), \
            "credentials.env file must exist"

    def test_wiz_client_id_variable_name(self):
        """Test that WIZ_CLIENT_ID is used (not WIZ_CLIENT)."""
        with open('/app/config/credentials.env', 'r') as f:
            content = f.read()
        
        assert 'WIZ_CLIENT_ID=' in content, \
            "Must use WIZ_CLIENT_ID (not WIZ_CLIENT)"
        
        lines = [l for l in content.split('\n') if l.startswith('WIZ_CLIENT=') and not l.startswith('WIZ_CLIENT_ID')]
        assert len(lines) == 0, \
            "Found incorrect variable WIZ_CLIENT - should be WIZ_CLIENT_ID"

    def test_wiz_client_secret_variable_name(self):
        """Test that WIZ_CLIENT_SECRET is used (not WIZ_SECRET)."""
        with open('/app/config/credentials.env', 'r') as f:
            content = f.read()
        
        assert 'WIZ_CLIENT_SECRET=' in content, \
            "Must use WIZ_CLIENT_SECRET (not WIZ_SECRET)"

    def test_scan_path_points_to_src(self):
        """Test that SCAN_PATH points to actual source code directory."""
        with open('/app/config/credentials.env', 'r') as f:
            content = f.read()
        
        for line in content.split('\n'):
            if line.startswith('SCAN_PATH='):
                path = line.split('=', 1)[1].strip()
                assert 'src' in path or 'app' in path, \
                    f"SCAN_PATH should point to source code, not '{path}'"
                assert 'build' not in path, \
                    "SCAN_PATH should not point to ./build (empty directory)"


class TestWizCLI:
    """Test that Wiz CLI is properly installed and accessible."""

    def test_wiz_cli_in_path(self):
        """Test that wiz command is available in PATH."""
        result = subprocess.run(
            ['which', 'wiz'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, \
            "wiz CLI must be installed and available in PATH"

    def test_wiz_cli_executable(self):
        """Test that wiz CLI is executable."""
        wiz_path = '/usr/local/bin/wiz'
        if os.path.exists(wiz_path):
            assert os.access(wiz_path, os.X_OK), \
                f"{wiz_path} must be executable"
        else:
            result = subprocess.run(['which', 'wiz'], capture_output=True, text=True)
            assert result.returncode == 0, "wiz must be in PATH"

    def test_wiz_cli_responds_to_help(self):
        """Test that wiz CLI responds to help command."""
        result = subprocess.run(
            ['wiz', 'help'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, \
            "wiz help command should succeed"


class TestScanCommand:
    """Test that scan command syntax is correct."""

    def test_scan_script_exists(self):
        """Test that wiz_scan.sh script exists."""
        assert os.path.exists('/app/scripts/wiz_scan.sh'), \
            "wiz_scan.sh script must exist"

    def test_scan_script_uses_correct_command(self):
        """Test that scan script uses 'wiz dir scan' not 'wiz scan repo'."""
        with open('/app/scripts/wiz_scan.sh', 'r') as f:
            content = f.read()
        
        assert 'wiz scan repo' not in content, \
            "Invalid command 'wiz scan repo' found - should use 'wiz dir scan'"
        
        assert 'wiz dir scan' in content or 'dir scan' in content, \
            "Scan script must use 'wiz dir scan' command"

    def test_scan_script_uses_correct_env_vars(self):
        """Test that scan script references correct environment variables."""
        with open('/app/scripts/wiz_scan.sh', 'r') as f:
            content = f.read()
        
        assert 'WIZ_CLIENT_ID' in content or 'wiz auth' in content, \
            "Scan script should use WIZ_CLIENT_ID for authentication"


class TestPipelineConfiguration:
    """Test that pipeline does not mask failures."""

    def test_pipeline_no_false_success(self):
        """Test that pipeline.yml does not use '|| true' to mask failures."""
        pipeline_files = ['/app/pipeline.yml', '/app/environment/pipeline.yml']
        
        for pf in pipeline_files:
            if os.path.exists(pf):
                with open(pf, 'r') as f:
                    content = f.read()
                
                auth_line_ok = True
                scan_line_ok = True
                
                for line in content.split('\n'):
                    if 'wiz auth' in line and '|| true' in line:
                        auth_line_ok = False
                    if 'wiz_scan' in line and '|| true' in line:
                        scan_line_ok = False
                    if 'wiz dir scan' in line and '|| true' in line:
                        scan_line_ok = False
                
                assert auth_line_ok, \
                    "Pipeline should not mask auth failures with '|| true'"
                assert scan_line_ok, \
                    "Pipeline should not mask scan failures with '|| true'"

    def test_scan_script_propagates_errors(self):
        """Test that wiz_scan.sh does not always exit 0."""
        with open('/app/scripts/wiz_scan.sh', 'r') as f:
            content = f.read()
        
        lines = content.strip().split('\n')
        last_lines = '\n'.join(lines[-10:])
        
        has_conditional_exit = (
            'exit $' in content or
            'exit 1' in content or
            'if [' in content
        )
        
        always_exits_zero = (
            content.strip().endswith('exit 0') and
            'exit 1' not in content and
            'exit $' not in content
        )
        
        assert not always_exits_zero or has_conditional_exit, \
            "Scan script should not unconditionally exit 0 - must propagate scan failures"


class TestScanExecution:
    """Test that scan actually executes and produces results."""

    def test_scan_target_directory_exists(self):
        """Test that the scan target directory exists and has files."""
        target_dirs = ['/app/src/app', '/app/src']
        
        found_valid = False
        for target in target_dirs:
            if os.path.exists(target) and os.path.isdir(target):
                files = os.listdir(target)
                if len(files) > 0:
                    found_valid = True
                    break
        
        assert found_valid, \
            "Scan target directory must exist and contain files"

    def test_scan_produces_results_file(self):
        """Test that running the scan produces a results file."""
        subprocess.run(
            ['bash', '/app/scripts/wiz_scan.sh'],
            capture_output=True,
            cwd='/app'
        )
        
        assert os.path.exists('/app/scan-results.json'), \
            "Scan must produce scan-results.json file"

    def test_scan_results_contain_findings(self):
        """Test that scan results contain actual vulnerability findings."""
        if not os.path.exists('/app/scan-results.json'):
            subprocess.run(
                ['bash', '/app/scripts/wiz_scan.sh'],
                capture_output=True,
                cwd='/app'
            )
        
        if os.path.exists('/app/scan-results.json'):
            with open('/app/scan-results.json', 'r') as f:
                try:
                    results = json.load(f)
                    
                    has_findings = (
                        'findings' in results or
                        'vulnerabilities' in results or
                        'summary' in results
                    )
                    assert has_findings, \
                        "Scan results must contain findings or summary"
                    
                    if 'summary' in results:
                        total = results['summary'].get('total', 0)
                        assert total >= 0, "Summary should have total count"
                        
                except json.JSONDecodeError:
                    pytest.fail("scan-results.json must be valid JSON")


class TestAuthentication:
    """Test that authentication is properly configured."""

    def test_auth_uses_correct_credentials(self):
        """Test that authentication uses the correct credential variable names."""
        with open('/app/scripts/wiz_scan.sh', 'r') as f:
            content = f.read()
        
        if 'wiz auth' in content:
            assert '$WIZ_CLIENT_ID' in content or '"$WIZ_CLIENT_ID"' in content or "'$WIZ_CLIENT_ID'" in content, \
                "Auth command should use $WIZ_CLIENT_ID"
            assert '$WIZ_CLIENT_SECRET' in content or '"$WIZ_CLIENT_SECRET"' in content or "'$WIZ_CLIENT_SECRET'" in content, \
                "Auth command should use $WIZ_CLIENT_SECRET"
