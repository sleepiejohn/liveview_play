defmodule Acture.Repo.Migrations.CreateLocalUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:local_users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:local_users, [:email])

    create table(:local_users_tokens) do
      add :local_user_id, references(:local_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:local_users_tokens, [:local_user_id])
    create unique_index(:local_users_tokens, [:context, :token])
  end
end
