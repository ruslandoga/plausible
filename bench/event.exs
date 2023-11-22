_conn = %Plug.Conn{
  assigns: %{},
  body_params: %{
    "domain" => "dummy.site",
    "name" => "pageview",
    "props" => "{}",
    "referrer" => "https://google.com",
    "revenue" => nil,
    "url" => "http://dummy.site/"
  },
  cookies: %{},
  halted: false,
  host: "localhost",
  method: "POST",
  params: %{},
  path_info: ["api", "event"],
  path_params: %{},
  port: 8000,
  private: %{
    :phoenix_view => %{_: PlausibleWeb.Api.ExternalView},
    :plug_session_fetch => :done,
    :plug_session => %{},
    :before_send => [],
    :phoenix_controller => PlausibleWeb.Api.ExternalController,
    :phoenix_action => :event,
    :phoenix_format => "json",
    :phoenix_endpoint => PlausibleWeb.Endpoint,
    :phoenix_router => PlausibleWeb.Router,
    :phoenix_layout => %{_: {PlausibleWeb.LayoutView, :app}},
    PlausibleWeb.Router => []
  },
  query_params: %{},
  query_string: "",
  remote_ip: {1, 1, 1, 1},
  req_cookies: %{},
  req_headers: [
    {"content-length", "128"},
    {"content-type", "application/json, text/plain"},
    {"host", "localhost:8000"},
    {"user-agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284"},
    {"x-forwarded-for", "1.1.1.1"}
  ],
  request_path: "/api/event",
  resp_body: nil,
  resp_cookies: %{},
  resp_headers: [
    {"cache-control", "max-age=0, private, must-revalidate"},
    {"x-request-id", "F5jzh_7V103l2LkAAQJF"},
    {"access-control-allow-credentials", "true"},
    {"access-control-allow-origin", "*"},
    {"access-control-expose-headers", ""}
  ],
  scheme: :http,
  script_name: [],
  state: :unset,
  status: nil
}

# params = %{}

conn = fn ->
  %Plug.Conn{
    assigns: %{},
    body_params: %{
      "domain" => "dummy.site",
      "name" => "pageview",
      "props" => "{}",
      "referrer" => "https://google.com",
      "revenue" => nil,
      "url" => "http://dummy.site/"
    },
    cookies: %{},
    halted: false,
    host: "localhost",
    method: "POST",
    params: %{},
    path_info: ["api", "event"],
    path_params: %{},
    port: 8000,
    private: %{
      :phoenix_view => %{_: PlausibleWeb.Api.ExternalView},
      :plug_session_fetch => :done,
      :plug_session => %{},
      :before_send => [],
      :phoenix_controller => PlausibleWeb.Api.ExternalController,
      :phoenix_action => :event,
      :phoenix_format => "json",
      :phoenix_endpoint => PlausibleWeb.Endpoint,
      :phoenix_router => PlausibleWeb.Router,
      :phoenix_layout => %{_: {PlausibleWeb.LayoutView, :app}},
      PlausibleWeb.Router => []
    },
    query_params: %{},
    query_string: "",
    remote_ip: {1, 1, 1, 1},
    req_cookies: %{},
    req_headers: [
      {"content-length", "128"},
      {"content-type", "application/json, text/plain"},
      {"host", "localhost:8000"},
      {"user-agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.#{:rand.uniform(3000) + 3000}.121 Safari/537.36 OPR/71.0.#{:rand.uniform(3000) + 3000}.284"},
      {"x-forwarded-for", "1.1.1.1"}
    ],
    request_path: "/api/event",
    resp_body: nil,
    resp_cookies: %{},
    resp_headers: [
      {"cache-control", "max-age=0, private, must-revalidate"},
      {"x-request-id", "F5jzh_7V103l2LkAAQJF"},
      {"access-control-allow-credentials", "true"},
      {"access-control-allow-origin", "*"},
      {"access-control-expose-headers", ""}
    ],
    scheme: :http,
    script_name: [],
    state: :unset,
    status: nil
  }
end

alias Plausible.Ingestion

Benchee.run(
  %{
    # "control" => fn -> Enum.each(1..1000, fn _ -> conn.() end) end,
    # "request_build" => fn -> Enum.each(1..1000, fn _ -> Ingestion.Request.build(conn.()) end) end,
    "/api/event" => fn ->
      # Enum.each(1..1000, fn _ ->
      with {:ok, request} <- Ingestion.Request.build(conn.()),
           _ <- Sentry.Context.set_extra_context(%{request: request}) do
        Ingestion.Event.build_and_buffer(request)
      end

      # end)
    end
  },
  profile_after: true
)
