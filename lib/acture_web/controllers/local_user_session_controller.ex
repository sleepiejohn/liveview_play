defmodule ActureWeb.LocalUserSessionController do
  use ActureWeb, :controller

  alias Acture.Accounts
  alias ActureWeb.LocalUserAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"local_user" => local_user_params}) do
    %{"email" => email, "password" => password} = local_user_params

    if local_user = Accounts.get_local_user_by_email_and_password(email, password) do
      LocalUserAuth.log_in_local_user(conn, local_user, local_user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> LocalUserAuth.log_out_local_user()
  end
end
