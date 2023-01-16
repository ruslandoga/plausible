defmodule Plausible.Google.Buffer do
  @moduledoc """
  This GenServer inserts records into Clickhouse `imported_*` tables. Multiple buffers are
  automatically created for each table. Records are flushed when the table buffer reaches the
  maximum size, defined by `max_buffer_size/0`.
  """

  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_opts) do
    {:ok, %{buffers: %{}}}
  end

  @spec insert_many(pid(), module(), [map()]) :: :ok
  @doc """
  Puts the given records into the table buffer.
  """
  def insert_many(pid, schema, records) when is_atom(schema) do
    GenServer.call(pid, {:insert_many, schema, records})
  end

  @spec size(pid(), term()) :: non_neg_integer()
  @doc """
  Returns the total count of items in the given table buffer.
  """
  def size(pid, schema) do
    GenServer.call(pid, {:get_size, schema})
  end

  @spec flush(pid()) :: :ok
  @doc """
  Flushes all table buffers to Clickhouse.
  """
  def flush(pid, timeout \\ :infinity) do
    GenServer.call(pid, :flush_all_buffers, timeout)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def handle_call({:get_size, schema}, _from, %{buffers: buffers} = state) do
    size =
      buffers
      |> Map.get(schema, [])
      |> length()

    {:reply, size, state}
  end

  def handle_call({:insert_many, schema, records}, _from, %{buffers: buffers} = state) do
    Logger.info("Import: Adding #{length(records)} to #{schema} buffer")

    new_buffer = Map.get(buffers, schema, []) ++ records
    new_state = put_in(state.buffers[schema], new_buffer)

    if length(new_buffer) >= max_buffer_size() do
      {:reply, :ok, new_state, {:continue, {:flush, schema}}}
    else
      {:reply, :ok, new_state}
    end
  end

  def handle_call(:flush_all_buffers, _from, state) do
    Enum.each(state.buffers, fn {schema, records} ->
      flush_buffer(records, schema)
    end)

    {:reply, :ok, put_in(state.buffers, %{})}
  end

  def handle_continue({:flush, schema}, state) do
    flush_buffer(state.buffers[schema], schema)
    {:noreply, put_in(state.buffers[schema], [])}
  end

  defp max_buffer_size do
    :plausible
    |> Application.get_env(:google)
    |> Keyword.fetch!(:max_buffer_size)
  end

  defp flush_buffer(records, schema) do
    # Clickhouse does not recommend sending more than 1 INSERT operation per second, and this
    # sleep call slows down the flushing
    Process.sleep(1000)

    Logger.info("Import: Flushing #{length(records)} from #{schema} buffer")
    Plausible.ClickhouseRepo.insert_all(schema, records)
  end
end
