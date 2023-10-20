defmodule Plausible.ExportTest do
  use Plausible.DataCase

  test "it works" do
    site = insert(:site)

    populate_stats(site, [
      build(:pageview, pathname: "/", timestamp: ~U[2023-10-20 20:00:00Z]),
      build(:pageview, pathname: "/about", timestamp: ~U[2023-10-20 20:01:00Z]),
      build(:pageview, pathname: "/signup", timestamp: ~U[2023-10-20 20:03:20Z])
    ])

    export = Plausible.Export.export(site.id)

    assert Map.keys(export) == [
             :browsers,
             :devices,
             :entry_pages,
             :exit_pages,
             :locations,
             :operating_systems,
             :pages,
             :sources,
             :visitors
           ]

    assert export.browsers == [
             %{
               bounces: 3,
               browser: "",
               date: ~D[2023-10-20],
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]

    assert export.devices == [
             %{
               bounces: 3,
               date: ~D[2023-10-20],
               device: "",
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]

    assert export.entry_pages == [
             %{
               bounces: 1,
               date: ~D[2023-10-20],
               entrances: 1,
               entry_page: "/signup",
               visit_duration: 0,
               visitors: 1
             },
             %{
               bounces: 1,
               date: ~D[2023-10-20],
               entrances: 1,
               entry_page: "/",
               visit_duration: 0,
               visitors: 1
             },
             %{
               bounces: 1,
               date: ~D[2023-10-20],
               entrances: 1,
               entry_page: "/about",
               visit_duration: 0,
               visitors: 1
             }
           ]

    assert export.exit_pages == [
             %{date: ~D[2023-10-20], exit_page: "/signup", exits: 1, visitors: 1},
             %{date: ~D[2023-10-20], exit_page: "/", exits: 1, visitors: 1},
             %{date: ~D[2023-10-20], exit_page: "/about", exits: 1, visitors: 1}
           ]

    # TODO region "" or nil
    assert export.locations == [
             %{
               bounces: 3,
               city: 0,
               country: <<0, 0>>,
               date: ~D[2023-10-20],
               region: "-",
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]

    assert export.operating_systems == [
             %{
               bounces: 3,
               date: ~D[2023-10-20],
               operating_system: "",
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]

    assert export.pages == [
             %{
               date: ~D[2023-10-20],
               exits: 1,
               hostname: "example-3.com",
               pageviews: 1,
               path: "/signup",
               time_on_page: 0,
               visitors: 1
             },
             %{
               date: ~D[2023-10-20],
               exits: 1,
               hostname: "example-1.com",
               pageviews: 1,
               path: "/",
               time_on_page: 0,
               visitors: 1
             },
             %{
               date: ~D[2023-10-20],
               exits: 1,
               hostname: "example-2.com",
               pageviews: 1,
               path: "/about",
               time_on_page: 0,
               visitors: 1
             }
           ]

    assert export.sources == [
             %{
               bounces: 3,
               date: ~D[2023-10-20],
               source: "",
               utm_campaign: "",
               utm_content: "",
               utm_term: "",
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]

    assert export.visitors == [
             %{
               bounces: 3,
               date: ~D[2023-10-20],
               pageviews: 3,
               visit_duration: 0,
               visitors: 3,
               visits: 3
             }
           ]
  end
end
