defmodule Plausible.Ingestion.WriteBuffer do
  @moduledoc false
  use GenServer
  require Logger

  alias Plausible.IngestRepo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  def insert(server, row_binary) do
    GenServer.cast(server, {:insert, row_binary})
  end

  def flush(server) do
    GenServer.call(server, :flush, :infinity)
  end

  @impl true
  def init(opts) do
    buffer = opts[:buffer] || []
    max_buffer_size = opts[:max_buffer_size] || default_max_buffer_size()
    flush_interval_ms = opts[:flush_interval_ms] || default_flush_interval_ms()

    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms)

    {:ok,
     %{
       buffer: buffer,
       timer: timer,
       last_insert_at: 0,
       name: Keyword.fetch!(opts, :name),
       insert_sql: Keyword.fetch!(opts, :insert_sql),
       insert_opts: Keyword.fetch!(opts, :insert_opts),
       header: Keyword.fetch!(opts, :header),
       buffer_size: IO.iodata_length(buffer),
       max_buffer_size: max_buffer_size,
       flush_interval_ms: flush_interval_ms
     }}
  end

  @impl true

  def handle_cast({:insert, row_binary}, state) do
    state = %{
      state
      | buffer: [state.buffer | row_binary],
        buffer_size: state.buffer_size + IO.iodata_length(row_binary)
    }

    ms_since_last_insert = now() - state.last_insert_at

    if state.buffer_size >= state.max_buffer_size and ms_since_last_insert >= :timer.seconds(1) do
      Logger.info("#{state.name} buffer full, flushing to ClickHouse")
      Process.cancel_timer(state.timer)
      do_flush(state)
      {:noreply, reset_buffer(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    do_flush(state)
    {:noreply, reset_buffer(state)}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    Process.cancel_timer(state.timer)
    do_flush(state)
    {:reply, :ok, reset_buffer(state)}
  end

  @impl true
  def terminate(_reason, %{name: name} = state) do
    Logger.info("Flushing #{name} buffer before shutdown...")
    do_flush(state)
  end

  defp do_flush(state) do
    %{
      buffer: buffer,
      buffer_size: buffer_size,
      insert_opts: insert_opts,
      insert_sql: insert_sql,
      header: header,
      name: name
    } = state

    case buffer do
      [] ->
        nil

      _not_empty ->
        Logger.info("Flushing #{buffer_size} byte(s) RowBinary from #{name}")
        IngestRepo.query!(insert_sql, [header | buffer], insert_opts)
    end
  end

  defp reset_buffer(state) do
    %{
      state
      | buffer: [],
        buffer_size: 0,
        last_insert_at: now(),
        timer: Process.send_after(self(), :tick, state.flush_interval_ms)
    }
  end

  defp default_flush_interval_ms do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :flush_interval_ms)
  end

  defp default_max_buffer_size do
    Keyword.fetch!(Application.get_env(:plausible, IngestRepo), :max_buffer_size)
  end

  @compile inline: [now: 0]
  defp now, do: System.system_time(:millisecond)

  @doc false
  def compile_time_prepare(schema) do
    fields = schema.__schema__(:fields)

    types =
      Enum.map(fields, fn field ->
        type = schema.__schema__(:type, field) || raise "missing type for #{field}"

        type
        |> Ecto.Type.type()
        |> Ecto.Adapters.ClickHouse.Schema.remap_type(schema, field)
      end)

    encoding_types = Ch.RowBinary.encoding_types(types)

    header =
      fields
      |> Enum.map(&to_string/1)
      |> Ch.RowBinary.encode_names_and_types(types)
      |> IO.iodata_to_binary()

    insert_sql = "INSERT INTO #{schema.__schema__(:source)} FORMAT RowBinaryWithNamesAndTypes"

    %{
      fields: fields,
      types: types,
      encoding_types: encoding_types,
      header: header,
      insert_sql: insert_sql,
      insert_opts: [
        command: :insert,
        encode: false,
        source: schema.__schema__(:source),
        cast_params: []
      ]
    }
  end
end
