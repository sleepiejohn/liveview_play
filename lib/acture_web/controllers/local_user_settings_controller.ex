defmodule ActureWeb.LocalUserSettingsController do
  use ActureWeb, :controller

  alias Acture.Accounts
  alias ActureWeb.LocalUserAuth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "local_user" => local_user_params} = params
    local_user = conn.assigns.current_local_user

    case Accounts.apply_local_user_email(local_user, password, local_user_params) do
      {:ok, applied_local_user} ->
        Accounts.deliver_update_email_instructions(
          applied_local_user,
          local_user.email,
          &Routes.local_user_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.local_user_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "local_user" => local_user_params} = params
    local_user = conn.assigns.current_local_user

    case Accounts.update_local_user_password(local_user, password, local_user_params) do
      {:ok, local_user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:local_user_return_to, Routes.local_user_settings_path(conn, :edit))
        |> LocalUserAuth.log_in_local_user(local_user)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_local_user_email(conn.assigns.current_local_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.local_user_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.local_user_settings_path(conn, :edit))
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    local_user = conn.assigns.current_local_user

    conn
    |> assign(:email_changeset, Accounts.change_local_user_email(local_user))
    |> assign(:password_changeset, Accounts.change_local_user_password(local_user))
  end
end
