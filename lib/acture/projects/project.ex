defmodule Acture.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :customer, :string
    field :description, :string
    field :estimated_completion_at, :date
    field :started_at, :date
    field :status, Ecto.Enum, values: [:ongoing, :halted, :waiting, :completed]
    field :title, :string

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:title, :description, :customer, :started_at, :estimated_completion_at, :status])
    |> validate_required([:title, :description, :customer, :started_at, :estimated_completion_at, :status])
  end
end
