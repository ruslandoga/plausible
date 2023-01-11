defmodule Plausible.Google.ImportedVisitor do
  use Ecto.Schema

  @primary_key false
  schema "imported_visitors" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :visitors, Ch.Types.UInt64
    field :pageviews, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
  end
end

defmodule Plausible.Google.ImportedSource do
  use Ecto.Schema

  @primary_key false
  schema "imported_sources" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :source, :string
    field :utm_medium, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string
    field :visitors, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end

defmodule Plausible.Google.ImportedPage do
  use Ecto.Schema

  @primary_key false
  schema "imported_pages" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :hostname, :string
    field :page, :string
    field :visitors, Ch.Types.UInt64
    field :pageviews, Ch.Types.UInt64
    field :exits, Ch.Types.UInt64
    field :time_on_page, Ch.Types.UInt64
  end
end

defmodule Plausible.Google.ImportedEntryPage do
  use Ecto.Schema

  @primary_key false
  schema "imported_entry_pages" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :entry_page, :string
    field :visitors, Ch.Types.UInt64
    field :entrances, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end

defmodule Plausible.Google.ImportedExitPage do
  use Ecto.Schema

  @primary_key false
  schema "imported_exit_pages" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :exit_page, :string
    field :visitors, Ch.Types.UInt64
    field :exits, Ch.Types.UInt64
  end
end

defmodule Plausible.Google.ImportedLocation do
  use Ecto.Schema

  @primary_key false
  schema "imported_locations" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :country, :string
    field :region, :string
    field :city, Ch.Types.UInt64
    field :visitors, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end

defmodule Plausible.Google.ImportedDevice do
  use Ecto.Schema

  @primary_key false
  schema "imported_devices" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :device, :string
    field :visitors, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end

defmodule Plausible.Google.ImportedBrowser do
  use Ecto.Schema

  @primary_key false
  schema "imported_devices" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :browser, :string
    field :visitors, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end

defmodule Plausible.Google.ImportedOperatingSystem do
  use Ecto.Schema

  @primary_key false
  schema "imported_operating_systems" do
    field :site_id, Ch.Types.UInt64
    field :date, :date
    field :operating_system, :string
    field :visitors, Ch.Types.UInt64
    field :visits, Ch.Types.UInt64
    field :visit_duration, Ch.Types.UInt64
    field :bounces, Ch.Types.UInt32
  end
end
