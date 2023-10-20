defmodule Plausible.Export do
  @moduledoc "Exports Plausible data for events and sessions."

  import Ecto.Query

  # TODO header
  # TODO sampling
  # TODO return queries
  # TODO queries can be streamed to compressed CSV (in ClickHouse) (export_stream_csv(query, compressed?))
  # TODO collect to a (streaming) zip archive (export_archive_stream(stream, archive))
  # TODO checksums (whole archive, each compressed CSV, each decompressed CSV)
  # TODO do in one pass over both tables?
  # TODO scheduling (limit parallel exports)
  def export(site_id) do
    [sessions_base_q, events_base_q] =
      for table <- ["sessions_v2", "events_v2"] do
        table
        |> where(site_id: ^site_id)
        |> group_by([], selected_as(:date))
        |> order_by([], selected_as(:date))
        |> select([t], %{date: selected_as(fragment("toDate(?)", t.timestamp), :date)})
      end

    exported_visitors_events_q =
      select_merge(events_base_q, [e], %{
        # TODO calc visitors from sessions?
        visitors: fragment("uniq(?)", e.user_id),
        pageviews: fragment("countIf(?='pageview')", e.name)
      })

    exported_visitors_sessions_q =
      select_merge(sessions_base_q, [s], %{
        bounces: sum(s.is_bounce * s.sign),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign))
      })

    exported_visitors =
      "e"
      |> with_cte("e", as: ^exported_visitors_events_q)
      |> with_cte("s", as: ^exported_visitors_sessions_q)
      # TODO test FULL OUTER JOIN in ch / ecto_ch
      |> join(:full, [e], s in "s", on: e.date == s.date)
      |> select([e, s], %{
        date: selected_as(coalesce(e.date, s.date), :date),
        visitors: e.visitors,
        pageviews: e.pageviews,
        bounces: s.bounces,
        visits: s.visits,
        visit_duration: s.visit_duration
      })
      |> order_by([], selected_as(:date))
      |> Plausible.ClickhouseRepo.all()

    exported_sources =
      sessions_base_q
      |> group_by([s], [
        selected_as(:date),
        s.utm_source,
        s.utm_campaign,
        s.utm_medium,
        s.utm_content,
        s.utm_term
      ])
      |> select_merge([s], %{
        source: s.utm_source,
        utm_campaign: s.utm_campaign,
        utm_content: s.utm_content,
        utm_term: s.utm_term,
        visitors: fragment("uniq(?)", s.user_id),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        bounces: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_pages_subquery =
      "events_v2"
      |> where(site_id: ^site_id)
      |> windows([e],
        before_and_after: [
          partition_by: e.session_id,
          order_by: e.timestamp,
          frame: fragment("ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING")
        ]
      )
      |> select([e], %{
        session_id: e.session_id,
        prev_timestamp: over(fragment("lagInFrame(?)", e.timestamp), :before_and_after),
        timestamp: e.timestamp,
        next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :before_and_after),
        pathname: e.pathname,
        hostname: e.hostname,
        name: e.name,
        user_id: e.user_id
      })

    exported_pages =
      subquery(exported_pages_subquery)
      |> select([e], %{
        date: selected_as(fragment("toDate(?)", e.timestamp), :date),
        path: selected_as(e.pathname, :path),
        hostname: fragment("any(?)", e.hostname),
        time_on_page:
          fragment("sumIf(?, ?)", e.timestamp - e.prev_timestamp, e.prev_timestamp != 0),
        exits: fragment("countIf(?=0)", e.next_timestamp),
        pageviews: fragment("countIf(?='pageview')", e.name),
        visitors: fragment("uniq(?)", e.user_id)
      })
      |> group_by([e], [selected_as(:date), selected_as(:path)])
      |> order_by([], selected_as(:date))
      |> Plausible.ClickhouseRepo.all()

    exported_entry_pages =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.entry_page])
      |> select_merge([s], %{
        entry_page: s.entry_page,
        visitors: fragment("uniq(?)", s.user_id),
        entrances: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        bounces: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_exit_pages =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.exit_page])
      |> select_merge([s], %{
        exit_page: s.exit_page,
        visitors: fragment("uniq(?)", s.user_id),
        exits: sum(s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_locations =
      sessions_base_q
      |> group_by([s], [
        selected_as(:date),
        s.country_code,
        selected_as(:region),
        s.city_geoname_id
      ])
      |> select_merge([s], %{
        country: s.country_code,
        # TODO
        region:
          selected_as(
            fragment("concatWithSeparator('-',?,?)", s.subdivision1_code, s.subdivision2_code),
            :region
          ),
        city: s.city_geoname_id,
        visitors: fragment("uniq(?)", s.user_id),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        bounces: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_devices =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.screen_size])
      |> select_merge([s], %{
        device: s.screen_size,
        visitors: fragment("uniq(?)", s.user_id),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        boucnes: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_browsers =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.browser])
      |> select_merge([s], %{
        browser: s.browser,
        visitors: fragment("uniq(?)", s.user_id),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        boucnes: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    exported_operating_systems =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.operating_system])
      |> select_merge([s], %{
        operating_system: s.operating_system,
        visitors: fragment("uniq(?)", s.user_id),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
        boucnes: sum(s.is_bounce * s.sign)
      })
      |> Plausible.ClickhouseRepo.all()

    %{
      visitors: exported_visitors,
      sources: exported_sources,
      pages: exported_pages,
      entry_pages: exported_entry_pages,
      exit_pages: exported_exit_pages,
      locations: exported_locations,
      devices: exported_devices,
      browsers: exported_browsers,
      operating_systems: exported_operating_systems
    }
  end
end
