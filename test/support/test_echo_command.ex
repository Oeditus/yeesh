defmodule Yeesh.Test.EchoCommand do
  @moduledoc false
  use Yeesh.MixCommand,
    task: "yeesh_test.echo",
    name: "test_echo",
    description: "Test echo via MixCommand macro",
    default_args: ["default_arg"]
end
