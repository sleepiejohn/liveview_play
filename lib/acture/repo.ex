defmodule Acture.Repo do
  use Ecto.Repo,
    otp_app: :acture,
    adapter: Ecto.Adapters.Postgres
end
