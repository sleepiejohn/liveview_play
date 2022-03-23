defmodule ActureWeb.LocalUserRegistrationController do
  use ActureWeb, :controller

  alias Acture.Accounts
  alias Acture.Accounts.LocalUser
  alias ActureWeb.LocalUserAuth

  def new(conn, _params) do
    changeset = Accounts.change_local_user_registration(%LocalUser{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"local_user" => local_user_params}) do
    case Accounts.register_local_user(local_user_params) do
      {:ok, local_user} ->
        {:ok, _} =
          Accounts.deliver_local_user_confirmation_instructions(
            local_user,
            &Routes.local_user_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "Local user created successfully.")
        |> LocalUserAuth.log_in_local_user(local_user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
