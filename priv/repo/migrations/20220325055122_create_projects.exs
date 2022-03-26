defmodule Acture.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :title, :string
      add :description, :string
      add :customer, :string
      add :started_at, :date
      add :estimated_completion_at, :date
      add :status, :string

      timestamps()
    end
  end
end
