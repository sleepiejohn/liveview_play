defmodule ActureWeb.LocalUserConfirmationControllerTest do
  use ActureWeb.ConnCase, async: true

  alias Acture.Accounts
  alias Acture.Repo
  import Acture.AccountsFixtures

  setup do
    %{local_user: local_user_fixture()}
  end

  describe "GET /local_users/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, Routes.local_user_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /local_users/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, local_user: local_user} do
      conn =
        post(conn, Routes.local_user_confirmation_path(conn, :create), %{
          "local_user" => %{"email" => local_user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Accounts.LocalUserToken, local_user_id: local_user.id).context == "confirm"
    end

    test "does not send confirmation token if Local user is confirmed", %{conn: conn, local_user: local_user} do
      Repo.update!(Accounts.LocalUser.confirm_changeset(local_user))

      conn =
        post(conn, Routes.local_user_confirmation_path(conn, :create), %{
          "local_user" => %{"email" => local_user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Accounts.LocalUserToken, local_user_id: local_user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.local_user_confirmation_path(conn, :create), %{
          "local_user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.LocalUserToken) == []
    end
  end

  describe "GET /local_users/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.local_user_confirmation_path(conn, :edit, "some-token"))
      response = html_response(conn, 200)
      assert response =~ "<h1>Confirm account</h1>"

      form_action = Routes.local_user_confirmation_path(conn, :update, "some-token")
      assert response =~ "action=\"#{form_action}\""
    end
  end

  describe "POST /local_users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, local_user: local_user} do
      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_local_user_confirmation_instructions(local_user, url)
        end)

      conn = post(conn, Routes.local_user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Local user confirmed successfully"
      assert Accounts.get_local_user!(local_user.id).confirmed_at
      refute get_session(conn, :local_user_token)
      assert Repo.all(Accounts.LocalUserToken) == []

      # When not logged in
      conn = post(conn, Routes.local_user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Local user confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_local_user(local_user)
        |> post(Routes.local_user_confirmation_path(conn, :update, token))

      assert redirected_to(conn) == "/"
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, local_user: local_user} do
      conn = post(conn, Routes.local_user_confirmation_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Local user confirmation link is invalid or it has expired"
      refute Accounts.get_local_user!(local_user.id).confirmed_at
    end
  end
end
