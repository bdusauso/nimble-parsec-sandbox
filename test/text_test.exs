defmodule TextTest do
  use ExUnit.Case
  doctest Text

  test "greets the world" do
    assert Text.hello() == :world
  end
end
