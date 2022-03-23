defmodule ActureWeb.LocalUserResetPasswordController do
  use ActureWeb, :controller

  alias Acture.Accounts

  plug :get_local_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"local_user" => %{"email" => email}}) do
    if local_user = Accounts.get_local_user_by_email(email) do
      Accounts.deliver_local_user_reset_password_instructions(
        local_user,
        &Routes.local_user_reset_password_url(conn, :edit, &1)
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Accounts.change_local_user_password(conn.assigns.local_user))
  end

  # Do not log in the local_user after reset password to avoid a
  # leaked token giving the local_user access to the account.
  def update(conn, %{"local_user" => local_user_params}) do
    case Accounts.reset_local_user_password(conn.assigns.local_user, local_user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.local_user_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_local_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if local_user = Accounts.get_local_user_by_reset_password_token(token) do
      conn |> assign(:local_user, local_user) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
