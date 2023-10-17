defmodule Plausible.Export do
  @moduledoc "Exports Plausible data for events and sessions."

  import Ecto.Query

  def export(site_id) do
    visitors =
      "sessions_v2"
      |> where(site_id: ^site_id)
      |> select([e], e.name)
      |> Plausible.ClickhouseRepo.all()



    %{visitors: }
  end
end
