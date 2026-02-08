Describe "Plugin system"
  Describe "validate_plugin_name()"
    It "accepts valid plugin names"
      When call validate_plugin_name "hello-lab"
      The status should be success
    End

    It "rejects invalid plugin names"
      When call validate_plugin_name "Hello Lab!"
      The status should be failure
      The stderr should include "Invalid plugin name"
    End
  End

  Describe "registry/index.json"
    It "is valid JSON"
      When run command jq '.' "$QLAB_ROOT/registry/index.json"
      The status should be success
      The output should be present
    End

    It "contains hello-lab entry"
      When run command jq -r '.[0].name' "$QLAB_ROOT/registry/index.json"
      The output should eq "hello-lab"
    End

    It "has a git_url for hello-lab"
      When run command jq -r '.[0].git_url' "$QLAB_ROOT/registry/index.json"
      The output should be present
    End

    It "has a description for hello-lab"
      When run command jq -r '.[0].description' "$QLAB_ROOT/registry/index.json"
      The output should be present
    End
  End
End
