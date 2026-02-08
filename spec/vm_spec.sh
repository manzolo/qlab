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
End
