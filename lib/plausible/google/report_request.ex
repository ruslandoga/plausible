defmodule Plausible.Google.ReportRequest do
  defstruct [
    :dataset,
    :dimensions,
    :metrics,
    :date_range,
    :view_id,
    :access_token,
    :page_token,
    :page_size
  ]

  alias Plausible.Google.{
    ImportedVisitor,
    ImportedSource,
    ImportedPage,
    ImportedEntryPage,
    ImportedExitPage,
    ImportedLocation,
    ImportedDevice,
    ImportedBrowser,
    ImportedOperatingSystem
  }

  @type dataset ::
          ImportedVisitor
          | ImportedSource
          | ImportedPage
          | ImportedEntryPage
          | ImportedExitPage
          | ImportedLocation
          | ImportedDevice
          | ImportedBrowser
          | ImportedOperatingSystem

  @type t() :: %__MODULE__{
          dataset: dataset,
          dimensions: [String.t()],
          metrics: [String.t()],
          date_range: Date.Range.t(),
          view_id: term(),
          access_token: String.t(),
          page_token: String.t() | nil,
          page_size: non_neg_integer()
        }

  def full_report do
    [
      %__MODULE__{
        dataset: ImportedVisitor,
        dimensions: ["ga:date"],
        metrics: ["ga:users", "ga:pageviews", "ga:bounces", "ga:sessions", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: ImportedSource,
        dimensions: [
          "ga:date",
          "ga:source",
          "ga:medium",
          "ga:campaign",
          "ga:adContent",
          "ga:keyword"
        ],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: ImportedPage,
        dimensions: ["ga:date", "ga:hostname", "ga:pagePath"],
        metrics: ["ga:users", "ga:pageviews", "ga:exits", "ga:timeOnPage"]
      },
      %__MODULE__{
        dataset: ImportedEntryPage,
        dimensions: ["ga:date", "ga:landingPagePath"],
        metrics: ["ga:users", "ga:entrances", "ga:sessionDuration", "ga:bounces"]
      },
      %__MODULE__{
        dataset: ImportedExitPage,
        dimensions: ["ga:date", "ga:exitPagePath"],
        metrics: ["ga:users", "ga:exits"]
      },
      %__MODULE__{
        dataset: ImportedLocation,
        dimensions: ["ga:date", "ga:countryIsoCode", "ga:regionIsoCode"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: ImportedDevice,
        dimensions: ["ga:date", "ga:deviceCategory"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: ImportedbBrowser,
        dimensions: ["ga:date", "ga:browser"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: ImportedOperatingSystem,
        dimensions: ["ga:date", "ga:operatingSystem"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      }
    ]
  end
end
