defmodule Plausible.ExportTest do
  use Plausible.DataCase

  test "it works" do
    assert Plausible.Export.export(1) == %{events: [], header: [["version"], ["1"]], sessions: []}
  end
end
