# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Acture.Repo.insert!(%Acture.SomeSchema{})
#
# We recommend u  sing the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Acture.{Accounts, Repo}

Accounts.register_local_user(%{email: "johndoe@example.com", password: "123123123123"})
