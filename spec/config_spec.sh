Describe "lib/config.bash"
  Describe "load_config()"
    setup() {
      TMPCONF=$(mktemp)
      cat > "$TMPCONF" <<'CONF'
# Comment line
KEY1=value1
KEY2=value2
DEFAULT_MEMORY=2048
CONF
    }

    cleanup() {
      rm -f "$TMPCONF"
    }

    Before "setup"
    After "cleanup"

    It "loads key-value pairs from a file"
      When call load_config "$TMPCONF"
      The status should be success
    End

    It "returns failure for missing file"
      When call load_config "/nonexistent/file"
      The status should be failure
      The stderr should include "not found"
    End
  End

  Describe "get_config()"
    setup() {
      declare -gA CONFIG
      CONFIG=()
      CONFIG[TEST_KEY]="test_value"
    }

    Before "setup"

    It "returns the value for an existing key"
      When call get_config "TEST_KEY"
      The output should eq "test_value"
    End

    It "returns default for a missing key"
      When call get_config "MISSING_KEY" "default_val"
      The output should eq "default_val"
    End

    It "returns empty for a missing key without default"
      When call get_config "MISSING_KEY"
      The output should eq ""
    End
  End
End
