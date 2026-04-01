defmodule Yeesh.OutputTest do
  use ExUnit.Case, async: true

  alias Yeesh.Output

  test "green wraps text with ANSI green" do
    result = Output.green("ok")
    assert result =~ "ok"
    assert result =~ "\e[32m"
    assert result =~ "\e[0m"
  end

  test "bold wraps text with ANSI bold" do
    result = Output.bold("title")
    assert result =~ "\e[1m"
    assert result =~ "title"
  end

  test "error formats with red prefix" do
    result = Output.error("something broke")
    assert result =~ "error:"
    assert result =~ "something broke"
  end

  test "warning formats with yellow prefix" do
    result = Output.warning("careful")
    assert result =~ "warning:"
    assert result =~ "careful"
  end
end
