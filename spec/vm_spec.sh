Describe "lib/vm.bash"
  Describe "check_port_available()"
    It "returns success for a free port"
      When call check_port_available 59999
      The status should be success
    End
    It "returns failure for a busy port"
      When call check_port_available 22
      The status should be failure
    End
    It "returns failure for non-numeric input"
      When call check_port_available "abc"
      The status should be failure
      The stderr should include "Invalid port"
    End
  End

  Describe "check_all_ports()"
    It "succeeds when all ports are free"
      When call check_all_ports 59999 "user,id=net0,hostfwd=tcp::59999-:22"
      The status should be success
    End
    It "fails when SSH port is busy"
      When call check_all_ports 22 "user,id=net0,hostfwd=tcp::22-:22"
      The status should be failure
      The stderr should include "already in use"
    End
    It "fails when an extra hostfwd port is busy"
      When call check_all_ports 59999 "user,id=net0,hostfwd=tcp::59999-:22,hostfwd=tcp::22-:80"
      The status should be failure
      The stderr should include "already in use"
    End
  End

  Describe "scan_plugin_ports()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      mkdir -p "$TEST_WS/plugins/fake-lab"
      cat > "$TEST_WS/plugins/fake-lab/run.sh" <<'SCRIPT'
SSH_PORT=2250
SCRIPT
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "finds SSH_PORT declarations in plugin run.sh"
      When call scan_plugin_ports
      The output should include "fake-lab:SSH_PORT:2250"
      The status should be success
    End
  End

  Describe "find_next_free_port()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      mkdir -p "$TEST_WS/plugins/a-lab"
      cat > "$TEST_WS/plugins/a-lab/run.sh" <<'SCRIPT'
SSH_PORT=2222
SCRIPT
      mkdir -p "$TEST_WS/plugins/b-lab"
      cat > "$TEST_WS/plugins/b-lab/run.sh" <<'SCRIPT'
SSH_PORT=2223
SCRIPT
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "returns the first unused port"
      When call find_next_free_port
      The output should eq "2224"
      The status should be success
    End
  End

  Describe "check_port_conflicts()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      mkdir -p "$TEST_WS/plugins/x-lab"
      cat > "$TEST_WS/plugins/x-lab/run.sh" <<'SCRIPT'
SSH_PORT=2250
SCRIPT
      mkdir -p "$TEST_WS/plugins/y-lab"
      cat > "$TEST_WS/plugins/y-lab/run.sh" <<'SCRIPT'
SSH_PORT=2250
SCRIPT
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "detects duplicate ports"
      When call check_port_conflicts
      The stderr should include "Port conflicts detected"
      The stderr should include "2250"
      The status should be failure
    End
  End
End
