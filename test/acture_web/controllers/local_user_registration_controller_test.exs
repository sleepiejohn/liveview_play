defmodule ActureWeb.LocalUserRegistrationControllerTest do
  use ActureWeb.ConnCase, async: true

  import Acture.AccountsFixtures

  describe "GET /local_users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.local_user_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_local_user(local_user_fixture()) |> get(Routes.local_user_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /local_users/register" do
    @tag :capture_log
    test "creates account and logs the local_user in", %{conn: conn} do
      email = unique_local_user_email()

      conn =
        post(conn, Routes.local_user_registration_path(conn, :create), %{
          "local_user" => valid_local_user_attributes(email: email)
        })

      assert get_session(conn, :local_user_token)
      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.local_user_registration_path(conn, :create), %{
          "local_user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
