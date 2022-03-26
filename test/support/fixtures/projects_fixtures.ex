defmodule Acture.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Acture.Projects` context.
  """

  @doc """
  Generate a project.
  """
  def project_fixture(attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> Enum.into(%{
        customer: "some customer",
        description: "some description",
        estimated_completion_at: ~D[2022-03-24],
        started_at: ~D[2022-03-24],
        status: :ongoing,
        title: "some title"
      })
      |> Acture.Projects.create_project()

    project
  end
end
