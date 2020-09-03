defmodule Text.ParserTest do
  use ExUnit.Case

  alias Text.Parser

  test "it accepts comma as parts delimiter" do
    str = ~s/keyId="ec0c29ef",algorithm="hs2019",headers="(request-target) digest (created)"/
    assert {:ok, _parts} = Parser.signature(str)
  end

  test "it accepts whitespaces as parts delimiter" do
    str = ~s/keyId="ec0c29ef" algorithm="hs2019" headers="(request-target) digest (created)"/
    assert {:ok, _parts} = Parser.signature(str)
  end
end
