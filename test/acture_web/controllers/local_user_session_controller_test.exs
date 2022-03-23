defmodule ActureWeb.LocalUserSessionControllerTest do
  use ActureWeb.ConnCase, async: true

  import Acture.AccountsFixtures

  setup do
    %{local_user: local_user_fixture()}
  end

  describe "GET /local_users/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.local_user_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Register</a>"
      assert response =~ "Forgot your password?</a>"
    end

    test "redirects if already logged in", %{conn: conn, local_user: local_user} do
      conn = conn |> log_in_local_user(local_user) |> get(Routes.local_user_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /local_users/log_in" do
    test "logs the local_user in", %{conn: conn, local_user: local_user} do
      conn =
        post(conn, Routes.local_user_session_path(conn, :create), %{
          "local_user" => %{"email" => local_user.email, "password" => valid_local_user_password()}
        })

      assert get_session(conn, :local_user_token)
      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ local_user.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the local_user in with remember me", %{conn: conn, local_user: local_user} do
      conn =
        post(conn, Routes.local_user_session_path(conn, :create), %{
          "local_user" => %{
            "email" => local_user.email,
            "password" => valid_local_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_acture_web_local_user_remember_me"]
      assert redirected_to(conn) == "/"
    end

    test "logs the local_user in with return to", %{conn: conn, local_user: local_user} do
      conn =
        conn
        |> init_test_session(local_user_return_to: "/foo/bar")
        |> post(Routes.local_user_session_path(conn, :create), %{
          "local_user" => %{
            "email" => local_user.email,
            "password" => valid_local_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end

    test "emits error message with invalid credentials", %{conn: conn, local_user: local_user} do
      conn =
        post(conn, Routes.local_user_session_path(conn, :create), %{
          "local_user" => %{"email" => local_user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /local_users/log_out" do
    test "logs the local_user out", %{conn: conn, local_user: local_user} do
      conn = conn |> log_in_local_user(local_user) |> delete(Routes.local_user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :local_user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the local_user is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.local_user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :local_user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
