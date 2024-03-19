defmodule PlausibleWeb.Live.CSVImport do
  use PlausibleWeb, :live_view

  use Phoenix.VerifiedRoutes,
    router: PlausibleWeb.Router,
    endpoint: PlausibleWeb.Endpoint

  alias Plausible.Imported.CSVImporter

  @impl true
  def mount(_params, session, socket) do
    %{"site_id" => site_id, "user_id" => user_id} = session
    importable_tables = Plausible.Imported.tables()

    socket =
      socket
      |> assign(
        site_id: site_id,
        user_id: user_id,
        date_range: nil,
        can_confirm?: false,
        uploaded_tables: %{},
        importable_tables: importable_tables
      )
      |> allow_upload(:import,
        accept: ~w[.csv],
        auto_upload: true,
        max_entries: length(importable_tables),
        max_file_size: _1GB = 1_000_000_000,
        external: &presign_upload/2,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    # TODO prevent submit with <enter> if not @can_confirm?
    ~H"""
    <div>
      <form action="#" method="post" phx-change="validate-upload-form" phx-submit="submit-upload-form">
        <.csv_picker upload={@uploads.import} />
        <.confirm_button date_range={@date_range} can_confirm?={@can_confirm?} />
      </form>
      <div class="mt-4 flex flex-wrap">
        <%= for table <- @importable_tables do %>
          <%= if entry_ref = @uploaded_tables[table] do %>
            <%= if entry = find_upload_entry(@uploads.import.entries, entry_ref) do %>
              <.table_upload entry={entry} errors={upload_errors(@uploads.import, entry)} />
            <% else %>
              <.table_upload_placeholder table={table} />
            <% end %>
          <% else %>
            <.table_upload_placeholder table={table} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp csv_picker(assigns) do
    ~H"""
    <label
      phx-drop-target={@upload.ref}
      class="flex items-center mx-auth border dark:border-gray-600 rounded p-4"
    >
      <div class="bg-indigo-200 dark:bg-indigo-700 rounded p-1 hover:bg-indigo-300 dark:hover:bg-indigo-600 transition cursor-pointer">
        <Heroicons.plus class="w-4 h-4" />
      </div>
      <span class="ml-2 text-sm text-gray-600 dark:text-gray-500">
        (or drag-and-drop here)
      </span>
      <.live_file_input upload={@upload} class="hidden" />
    </label>
    """
  end

  defp confirm_button(assigns) do
    ~H"""
    <button
      type="submit"
      disabled={not @can_confirm?}
      class="inline-flex items-center justify-center gap-x-2 rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:bg-gray-400 dark:disabled:text-gray-400 dark:disabled:bg-gray-700 mt-4"
    >
      <%= if @date_range do %>
        Confirm import from <%= @date_range.first || "YYYY-MM-DD" %> to <%= @date_range.last %>
      <% else %>
        Confirm import
      <% end %>
    </button>
    """
  end

  defp table_upload(assigns) do
    bg =
      cond do
        assigns.entry.progress == 100 -> "dark:bg-green-600"
        not Enum.empty?(assigns.errors) -> "dark:bg-red-600"
        true -> "bg-gray-100 dark:bg-gray-700"
      end

    assigns = assign(assigns, bg: bg)

    ~H"""
    <div class={"mt-2 w-full rounded overflow-hidden " <> @bg}>
      <div class="flex items-center justify-between">
        <div class="p-2 flex items-center space-x-2">
          <Heroicons.document_check
            :if={@entry.progress == 100}
            class="w-4 h-4 text-indigo-600 dark:text-green-900"
          />
          <PlausibleWeb.Components.Generic.spinner
            :if={@entry.progress < 100}
            class="h-4 w-4 text-indigo-600 dark:text-green-600"
          />
          <span class="text-sm"><%= @entry.client_name %></span>
        </div>

        <button
          phx-click="cancel-upload"
          phx-value-ref={@entry.ref}
          class="m-2 flex rounded items-center justify-center hover:bg-indigo-300 dark:hover:bg-indigo-500 transition"
        >
          <Heroicons.x_mark class="h-4 w-4" />
        </button>
      </div>
    </div>

    <%= for error <- @errors do %>
      <p class="text-sm dark:text-red-800"><%= error_to_string(error) %></p>
    <% end %>
    """
  end

  defp table_upload_placeholder(assigns) do
    ~H"""
    <div class="mt-2 w-full bg-gray-100 dark:bg-gray-700 dark:text-gray-400 rounded overflow-hidden">
      <div class="flex items-center justify-between">
        <div class="p-2 flex items-center space-x-2">
          <Heroicons.document class="w-4 h-4" />
          <span class="text-sm"><%= @table %>_YYYYMMDD_YYYYMMDD.csv</span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate-upload-form", _params, socket) do
    {_uploaded, in_progress} = uploaded_entries(socket, :import)

    socket =
      Enum.reduce(in_progress, socket, fn entry, socket ->
        %{
          uploaded_tables: uploaded_tables,
          date_range: prev_date_range
        } =
          socket.assigns

        parsed =
          try do
            CSVImporter.parse_filename!(entry.client_name)
          rescue
            _ -> nil
          end

        if parsed do
          {table, start_date, end_date} = parsed

          socket =
            if prev_entry_ref = Map.get(uploaded_tables, table) do
              unless prev_entry_ref == entry.ref do
                cancel_upload(socket, :import, prev_entry_ref)
              end
            end || socket

          date_range = min_max_date_range(prev_date_range, start_date, end_date)
          uploaded_tables = Map.put(uploaded_tables, table, entry.ref)
          assign(socket, uploaded_tables: uploaded_tables, date_range: date_range)
        else
          cancel_upload(socket, :import, entry.ref)
        end
      end)

    {:noreply, socket}
  end

  def handle_event("submit-upload-form", _params, socket) do
    %{site_id: site_id, user_id: user_id, date_range: date_range} = socket.assigns
    site = Plausible.Repo.get!(Plausible.Site, site_id)
    user = Plausible.Repo.get!(Plausible.Auth.User, user_id)

    uploads =
      consume_uploaded_entries(socket, :import, fn meta, entry ->
        {:ok, %{"s3_url" => meta.s3_url, "filename" => entry.client_name}}
      end)

    # provided :source is set, this call cannot fail
    # so we are not handling {:error, changeset} here
    {:ok, _job} =
      CSVImporter.new_import(site, user,
        start_date: date_range.first,
        end_date: date_range.last,
        uploads: uploads
      )

    {:noreply, redirect(socket, to: ~p"/#{site.domain}/settings/imports-exports")}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    # TODO update min max date range
    # TODO update tables
    {:noreply, socket |> cancel_upload(:import, ref) |> check_if_can_confirm()}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(error), do: to_string(error)

  defp presign_upload(entry, socket) do
    %{s3_url: s3_url, presigned_url: upload_url} =
      Plausible.S3.import_presign_upload(socket.assigns.site_id, entry.client_name)

    {:ok, %{uploader: "S3", s3_url: s3_url, url: upload_url}, socket}
  end

  defp handle_progress(:import, entry, socket) do
    IO.inspect(entry, label: "progress")

    if entry.done? do
      {:noreply, check_if_can_confirm(socket)}
    else
      {:noreply, socket}
    end
  end

  defp check_if_can_confirm(socket) do
    all_uploaded? =
      case uploaded_entries(socket, :import) do
        {[_ | _] = _completed, [] = _in_progress} -> true
        {_completed, _in_progress} -> false
      end

    assign(socket, can_confirm?: all_uploaded?)
  end

  defp min_max_date_range(nil, start_date, end_date) do
    Date.range(start_date, end_date)
  end

  defp min_max_date_range(%Date.Range{} = date_range, start_date, end_date) do
    first = Enum.min([date_range.first, start_date], Date)
    last = Enum.max([date_range.last, end_date], Date)
    Date.range(first, last)
  end

  defp find_upload_entry(entries, ref) do
    Enum.find(entries, fn entry -> entry.ref == ref end)
  end
end
