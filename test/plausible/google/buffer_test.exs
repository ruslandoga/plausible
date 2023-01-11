defmodule Plausible.Google.BufferTest do
  use Plausible.DataCase, async: false
  alias Plausible.Google.{ImportedVisitor, ImportedSource, ImportedOperatingSystem}

  import Ecto.Query
  alias Plausible.Google.Buffer

  setup [:create_user, :create_new_site, :set_buffer_size]

  defp set_buffer_size(_setup_args) do
    google_setting = Application.get_env(:plausible, :google)
    patch_env(:google, Keyword.put(google_setting, :max_buffer_size, 10))
    :ok
  end

  defp imported_count(%{id: site_id}, table_name) do
    table_name
    |> from()
    |> where([record], record.site_id == ^site_id)
    |> Plausible.ClickhouseRepo.aggregate(:count)
  end

  defp build_records(count, factory_name, site) do
    count
    |> build_list(factory_name, site_id: site.id)
    |> Enum.map(&Map.drop(&1, [:table]))
  end

  test "insert_many/3 flushes when buffer reaches limit", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(9, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, ImportedVisitor, imported_visitors)
    assert Buffer.size(pid, ImportedVisitor) == 9
    assert imported_count(site, ImportedVisitor) == 0, "expected not to have flushed"

    imported_visitors = build_records(1, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, ImportedVisitor, imported_visitors)
    assert Buffer.size(pid, ImportedVisitor) == 0
    assert imported_count(site, ImportedVisitor) == 10, "expected to have flushed"
  end

  @tag :slow
  test "insert_many/3 uses separate buffers for each table", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(9, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, ImportedVisitor, imported_visitors)
    assert Buffer.size(pid, ImportedVisitor) == 9
    assert imported_count(site, ImportedVisitor) == 0, "expected not to have flushed"

    imported_sources = build_records(1, :imported_sources, site)
    assert :ok == Buffer.insert_many(pid, ImportedSource, imported_sources)
    assert Buffer.size(pid, ImportedSource) == 1
    assert imported_count(site, ImportedVisitor) == 0, "expected not to have flushed"

    imported_visitors = build_records(1, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, ImportedVisitor, imported_visitors)
    assert Buffer.size(pid, ImportedVisitor) == 0
    assert imported_count(site, ImportedVisitor) == 10, "expected to have flushed"

    imported_sources = build_records(9, :imported_sources, site)
    assert :ok == Buffer.insert_many(pid, ImportedSource, imported_sources)
    assert Buffer.size(pid, ImportedSource) == 0
    assert imported_count(site, ImportedSource) == 10, "expected to have flushed"
  end

  test "insert_many/3 flushes buffer automatically with many records", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_visitors = build_records(50, :imported_visitors, site)
    assert :ok == Buffer.insert_many(pid, ImportedVisitor, imported_visitors)
    assert Buffer.size(pid, ImportedVisitor) == 0
    assert imported_count(site, ImportedVisitor) == 50, "expected to have flushed"
  end

  @tag :slow
  test "flush/2 flushes all buffers", %{site: site} do
    {:ok, pid} = Buffer.start_link()

    imported_sources = build_records(1, :imported_sources, site)
    Buffer.insert_many(pid, ImportedSource, imported_sources)

    imported_visitors = build_records(1, :imported_visitors, site)
    Buffer.insert_many(pid, ImportedVisitor, imported_visitors)

    imported_operating_systems = build_records(2, :imported_operating_systems, site)
    Buffer.insert_many(pid, ImportedOperatingSystem, imported_operating_systems)

    assert :ok == Buffer.flush(pid, :timer.seconds(4))

    assert Buffer.size(pid, ImportedSource) == 0
    assert Buffer.size(pid, ImportedVisitor) == 0
    assert Buffer.size(pid, ImportedOperatingSystem) == 0

    assert imported_count(site, ImportedSource) == 1
    assert imported_count(site, ImportedVisitor) == 1
    assert imported_count(site, ImportedOperatingSystem) == 2
  end
end
