defmodule Yeesh.SandboxTest do
  use ExUnit.Case, async: true

  alias Yeesh.Sandbox

  describe "new_session/1" do
    test "creates a new session" do
      session = Sandbox.new_session()
      assert is_tuple(session)
    end
  end

  describe "eval/2" do
    test "evaluates simple expression" do
      session = Sandbox.new_session()
      assert {:ok, "7", "", _new_session} = Sandbox.eval(session, "3 + 4")
    end

    test "state persists across evaluations" do
      session = Sandbox.new_session()
      {:ok, _, _, session} = Sandbox.eval(session, "x = 42")
      assert {:ok, "42", "", _session} = Sandbox.eval(session, "x")
    end

    test "captures stdio" do
      session = Sandbox.new_session()
      {:ok, _inspected, stdio, _session} = Sandbox.eval(session, ~s|IO.puts("hello")|)
      assert stdio =~ "hello"
    end

    test "returns error for restricted functions" do
      session = Sandbox.new_session()
      assert {:error, message, _session} = Sandbox.eval(session, "File.cwd!()")
      assert message =~ "restricted"
    end

    test "returns error for syntax errors" do
      session = Sandbox.new_session()
      assert {:error, _message, _session} = Sandbox.eval(session, "][")
    end
  end
end
