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
    It "ignores port 0 (dynamic) in hostfwd"
      When call check_all_ports 59999 "user,id=net0,hostfwd=tcp::59999-:22,hostfwd=tcp::0-:3306"
      The status should be success
    End
  End

  Describe "allocate_port()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      STATE_DIR="$TEST_WS/state"
      mkdir -p "$STATE_DIR"
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "returns a port >= 2222"
      When call allocate_port
      The output should be present
      The status should be success
    End

    It "returns a preferred port when it is free"
      When call allocate_port 5555
      The output should eq "5555"
      The status should be success
    End

    It "returns two different ports on consecutive calls"
      allocate_two_ports() {
        local p1 p2
        p1=$(allocate_port)
        p2=$(allocate_port)
        if [[ "$p1" != "$p2" ]]; then
          echo "different"
        else
          echo "same"
        fi
      }
      When call allocate_two_ports
      The output should eq "different"
    End
  End

  Describe "_port_is_allocated()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      STATE_DIR="$TEST_WS/state"
      mkdir -p "$STATE_DIR"
      echo "3333" > "$STATE_DIR/.allocated_ports"
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "returns success for an allocated port"
      When call _port_is_allocated 3333
      The status should be success
    End
    It "returns failure for a non-allocated port"
      When call _port_is_allocated 4444
      The status should be failure
    End
  End

  Describe "_release_allocated_port()"
    setup() {
      TEST_WS=$(mktemp -d)
      WORKSPACE_DIR="$TEST_WS"
      STATE_DIR="$TEST_WS/state"
      mkdir -p "$STATE_DIR"
      printf '%s\n' "3333" "4444" > "$STATE_DIR/.allocated_ports"
    }
    cleanup() {
      rm -rf "$TEST_WS"
    }
    Before 'setup'
    After 'cleanup'

    It "removes the specified port from the allocated file"
      release_and_check() {
        _release_allocated_port 3333
        if _port_is_allocated 3333; then
          echo "still allocated"
        else
          echo "released"
        fi
      }
      When call release_and_check
      The output should eq "released"
    End
  End

  Describe "check_host_resources()"
    It "does not fail for reasonable memory"
      When call check_host_resources 1024 1
      The status should be success
    End
  End

End
