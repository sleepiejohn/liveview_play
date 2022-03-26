defmodule ActureWeb.ProjectLive.Presenter do
  alias Acture.DateTimeFormat

  def present_for_index(project, timezone) do
    %{
      project
      | started_at: DateTimeFormat.relative(project.started_at, timezone),
        estimated_completion_at:
          DateTimeFormat.relative(project.estimated_completion_at, timezone),
        status: String.capitalize(to_string(project.status))
    }
  end
end
