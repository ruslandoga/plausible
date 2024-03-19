defmodule PlausibleWeb.Live.CSVImport do
  use PlausibleWeb, :live_view
  alias Plausible.Imported.CSVImporter

  @impl true
  def mount(_params, session, socket) do
    %{"site_id" => site_id, "user_id" => user_id} = session

    socket =
      socket
      |> assign(site_id: site_id, user_id: user_id)
      |> allow_upload(:import,
        accept: ~w[.csv],
        auto_upload: true,
        max_entries: length(Plausible.Imported.tables()),
        max_file_size: _1GB = 1_000_000_000,
        external: &presign_upload/2,
        progress: &handle_progress/3
      )
      |> process_imported_tables()

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

        <p :for={error <- upload_errors(@uploads.import)} class="text-red-400">
          <%= error_to_string(error) %>
        </p>
      </form>
      <div id="imported-tables" class="mt-4 flex flex-wrap">
        <.imported_table
          :for={{table, upload} <- @imported_tables}
          table={table}
          upload={upload}
          errors={if(upload, do: upload_errors(@uploads.import, upload), else: [])}
        />
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

  defp imported_table(assigns) do
    status =
      cond do
        assigns.upload && assigns.upload.progress == 100 -> :success
        not Enum.empty?(assigns.errors) -> :error
        true -> :in_progress
      end

    assigns = assign(assigns, status: status)

    ~H"""
    <div
      id={@table}
      class={[
        "mt-2 w-full rounded overflow-hidden",
        case @status do
          :success -> "bg-green-300 dark:bg-green-600"
          :error -> "bg-red-300 dark:bg-red-600"
          :in_progress -> "bg-gray-100 dark:bg-gray-700"
        end
      ]}
    >
      <div class="flex items-center justify-between">
        <%= if @upload do %>
          <Heroicons.document_check
            :if={@upload.progress == 100}
            class="w-4 h-4 text-indigo-600 dark:text-green-900"
          />
          <PlausibleWeb.Components.Generic.spinner
            :if={@upload.progress < 100}
            class="h-4 w-4 text-indigo-600 dark:text-green-600"
          />
          <span class="text-sm"><%= @upload.client_name %></span>

          <button
            phx-click="cancel-upload"
            phx-value-ref={@upload.ref}
            class="m-2 flex rounded items-center justify-center hover:bg-indigo-300 dark:hover:bg-indigo-500 transition"
          >
            <Heroicons.x_mark class="h-4 w-4" />
          </button>
        <% else %>
          <div class="p-2 flex items-center space-x-2">
            <Heroicons.document class="w-4 h-4" />
            <span class="text-sm"><%= @table %>_YYYYMMDD_YYYYMMDD.csv</span>
          </div>
        <% end %>
      </div>
    </div>

    <p :for={error <- @errors} class="text-sm dark:text-red-800"><%= error_to_string(error) %></p>
    """
  end

  @impl true
  def handle_event("validate-upload-form", _params, socket) do
    {:noreply, process_imported_tables(socket)}
  end

  def handle_event("submit-upload-form", _params, socket) do
    %{site_id: site_id, user_id: user_id, date_range: date_range} = socket.assigns
    site = Plausible.Repo.get!(Plausible.Site, site_id)
    user = Plausible.Repo.get!(Plausible.Auth.User, user_id)

    uploads =
      consume_uploaded_entries(socket, :import, fn meta, entry ->
        {:ok, %{"s3_url" => meta.s3_url, "filename" => entry.client_name}}
      end)

    {:ok, _job} =
      CSVImporter.new_import(site, user,
        start_date: date_range.first,
        end_date: date_range.last,
        uploads: uploads
      )

    {:noreply,
     redirect(socket,
       to: Routes.site_path(socket, :settings_imports_exports, URI.encode_www_form(site.domain))
     )}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, socket |> cancel_upload(:import, ref) |> process_imported_tables()}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:external_client_failure), do: "Browser upload failed"

  defp presign_upload(entry, socket) do
    %{s3_url: s3_url, presigned_url: upload_url} =
      Plausible.S3.import_presign_upload(socket.assigns.site_id, entry.client_name)

    {:ok, %{uploader: "S3", s3_url: s3_url, url: upload_url}, socket}
  end

  defp handle_progress(:import, entry, socket) do
    if entry.done? do
      {:noreply, process_imported_tables(socket)}
    else
      {:noreply, socket}
    end
  end

  defp process_imported_tables(socket) do
    tables = Plausible.Imported.tables()
    {completed, in_progress} = uploaded_entries(socket, :import)

    {valid_uploads, invalid_uploads} =
      Enum.split_with(completed ++ in_progress, &CSVImporter.valid_filename?(&1.client_name))

    imported_tables =
      Enum.map(tables, fn table ->
        upload =
          Enum.find(valid_uploads, fn upload ->
            CSVImporter.extract_table(upload.client_name) == table
          end)

        {table, upload}
      end)

    date_range = CSVImporter.date_range(Enum.map(valid_uploads, & &1.client_name))
    all_uploaded? = completed != [] and in_progress == []

    socket =
      Enum.reduce(invalid_uploads, socket, fn upload, socket ->
        cancel_upload(socket, :import, upload.ref)
      end)

    assign(socket,
      imported_tables: imported_tables,
      date_range: date_range,
      can_confirm?: all_uploaded?
    )
  end
end
