defmodule Acture.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Acture.Repo

  alias Acture.Projects.Project

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects(paging \\ []) do
    from(p in Project,
      order_by: ^dyn_order_by(paging[:sort])
    )
    |> Repo.all()
  end

  defp dyn_order_by(sort) do
    IO.inspect(sort, label: "sort")

    case sort do
      {"customer", "asc"} -> [asc: :customer]
      {"customer", "desc"} -> [desc: :customer]
      {"started_at", "asc"} -> [asc: :started_at]
      {"started_at", "desc"} -> [desc: :started_at]
      {"estimated_completion_at", "asc"} -> [asc: :estimated_completion_at]
      {"estimated_completion_at", "desc"} -> [desc: :estimated_completion_at]
      {"status", "asc"} -> [asc: :status]
      {"status", "desc"} -> [desc: :status]
      {"title", "asc"} -> [asc: :title]
      {"title", "desc"} -> [desc: :title]
      _ -> [asc: :title]
    end
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end
end
