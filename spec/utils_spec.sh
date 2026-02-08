Describe "lib/utils.bash"
  Describe "validate_plugin_name()"
    It "accepts lowercase names"
      When call validate_plugin_name "hello-lab"
      The status should be success
    End

    It "accepts names with underscores"
      When call validate_plugin_name "my_plugin"
      The status should be success
    End

    It "accepts names with digits"
      When call validate_plugin_name "lab123"
      The status should be success
    End

    It "rejects names with uppercase"
      When call validate_plugin_name "HelloLab"
      The status should be failure
      The stderr should include "Invalid plugin name"
    End

    It "rejects names with spaces"
      When call validate_plugin_name "hello lab"
      The status should be failure
      The stderr should include "Invalid plugin name"
    End

    It "rejects names with special characters"
      When call validate_plugin_name "hello@lab"
      The status should be failure
      The stderr should include "Invalid plugin name"
    End

    It "rejects empty names"
      When call validate_plugin_name ""
      The status should be failure
      The stderr should include "Invalid plugin name"
    End
  End

  Describe "info()"
    # Wrap to avoid collision with system 'info' command
    qlab_info() { info "$@"; }
    It "outputs message with INFO prefix"
      When call qlab_info "test message"
      The output should include "[INFO]"
      The output should include "test message"
    End
  End

  Describe "warn()"
    It "outputs message with WARN prefix to stderr"
      When call warn "warning message"
      The stderr should include "[WARN]"
      The stderr should include "warning message"
    End
  End

  Describe "error()"
    # Wrap to avoid collision with shellspec internal 'error'
    qlab_error() { error "$@"; }
    It "outputs message with ERROR prefix to stderr"
      When call qlab_error "error message"
      The stderr should include "[ERROR]"
      The stderr should include "error message"
    End
  End

  Describe "success()"
    It "outputs message with OK prefix"
      When call success "done"
      The output should include "[OK]"
      The output should include "done"
    End
  End

  Describe "check_dependency()"
    It "succeeds for bash"
      When call check_dependency "bash"
      The status should be success
    End

    It "fails for nonexistent command"
      When call check_dependency "nonexistent_command_xyz"
      The status should be failure
      The stderr should include "not found"
    End
  End
End
