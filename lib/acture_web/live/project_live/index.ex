defmodule ActureWeb.ProjectLive.Index do
  use ActureWeb, :live_view

  alias Acture.Projects
  alias Acture.Projects.Project
  alias ActureWeb.ProjectLive.Presenter

  @allowed_sort ~w(title customer started_at estimated_completion_at status)
  @allowed_dir ~w(asc desc)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :projects, list_projects(socket.assigns.browser_context))}
  end

  def handle_params(%{"sort" => sort, "direction" => dir}, _url, socket) do
    cond do
      sort in @allowed_sort and dir in @allowed_dir ->
        {:noreply,
         assign(
           socket,
           :projects,
           list_projects(socket.assigns.browser_context, sort: {sort, dir})
         )}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Project")
    |> assign(:project, Projects.get_project!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Project")
    |> assign(:project, %Project{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Projects")
    |> assign(:project, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Projects.get_project!(id)
    {:ok, _} = Projects.delete_project(project)
    {:noreply, assign(socket, :projects, list_projects(socket.assigns.browser_context))}
  end

  defp list_projects(browser_context, paging \\ []) do
    %{timezone: timezone} = browser_context

    Projects.list_projects(paging)
    |> Enum.map(&Presenter.present_for_index(&1, timezone))
  end
end
