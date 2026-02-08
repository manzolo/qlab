Describe "Plugin system"
  Describe "validate_plugin_name()"
    It "accepts valid plugin names"
      When call validate_plugin_name "hello-lab"
      The status should be success
    End

    It "rejects invalid plugin names"
      When call validate_plugin_name "Hello Lab!"
      The status should be failure
    End
  End

  Describe "hello-lab plugin.conf"
    It "is valid JSON"
      When run command jq '.' "$QLAB_ROOT/plugins/hello-lab/plugin.conf"
      The status should be success
    End

    It "has a name field"
      When run command jq -r '.name' "$QLAB_ROOT/plugins/hello-lab/plugin.conf"
      The output should eq "hello-lab"
    End

    It "has a description field"
      When run command jq -r '.description' "$QLAB_ROOT/plugins/hello-lab/plugin.conf"
      The output should be present
    End

    It "has a version field"
      When run command jq -r '.version' "$QLAB_ROOT/plugins/hello-lab/plugin.conf"
      The output should eq "1.0"
    End
  End

  Describe "registry/index.json"
    It "is valid JSON"
      When run command jq '.' "$QLAB_ROOT/registry/index.json"
      The status should be success
    End

    It "contains hello-lab entry"
      When run command jq -r '.[0].name' "$QLAB_ROOT/registry/index.json"
      The output should eq "hello-lab"
    End
  End
End
