:ets.new(:sessions_alt, [
  :set,
  :named_table,
  :public,
  write_concurrency: :auto,
  read_concurrency: true
])

Benchee.run(
  %{
    "Session Balancers" => fn events ->
      Enum.each(events, fn event ->
        Plausible.Session.CacheStore.on_event(event, %{}, nil,
          buffer_insert: &Function.identity/1
        )
      end)
    end,
    "ConCache" => fn events ->
      Enum.each(events, fn event ->
        Plausible.Session.CacheStore.old_on_event(event, %{}, nil, &Function.identity/1)
      end)
    end,
    "insert_new" => fn events ->
      Enum.each(events, fn event ->
        {_user_id, session, counts} =
          case :ets.lookup(:sessions_alt, event.user_id) do
            [{_user_id, _session, _counts} = record] ->
              record

            [] ->
              session = Plausible.Session.CacheStore.new_session_from_event(event, %{})
              counts = :counters.new(2, [])
              record = {event.user_id, session, counts}

              case :ets.insert_new(:sessions_alt, record) do
                true ->
                  record

                false ->
                  [record] = :ets.lookup(:sessions_alt, event.user_id)
                  record
              end
          end

        :counters.add(counts, 1, 1)
        :counters.add(counts, 2, 1)
        %{session | pageviews: :counters.get(counts, 1), events: :counters.get(counts, 2)}
      end)
    end
  },
  before_scenario: fn inputs ->
    Enum.each(Plausible.Cache.Adapter.get_names(:sessions), fn cache ->
      :ets.delete_all_objects(ConCache.ets(cache))
    end)

    inputs
  end,
  inputs: %{
    "5k pageviews" =>
      Enum.map(1..5000, fn i ->
        %Plausible.ClickhouseEventV2{
          name: "pageview",
          user_id: Enum.random(1000..1500),
          hostname: "hostname",
          site_id: Enum.random(1000..1100),
          pathname: "/" <> String.duplicate("a", Enum.random(1..10)),
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)
  },
  parallel: 20
)
