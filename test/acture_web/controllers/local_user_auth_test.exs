defmodule ActureWeb.LocalUserAuthTest do
  use ActureWeb.ConnCase, async: true

  alias Acture.Accounts
  alias ActureWeb.LocalUserAuth
  import Acture.AccountsFixtures

  @remember_me_cookie "_acture_web_local_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ActureWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{local_user: local_user_fixture(), conn: conn}
  end

  describe "log_in_local_user/3" do
    test "stores the local_user token in the session", %{conn: conn, local_user: local_user} do
      conn = LocalUserAuth.log_in_local_user(conn, local_user)
      assert token = get_session(conn, :local_user_token)
      assert get_session(conn, :live_socket_id) == "local_users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert Accounts.get_local_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, local_user: local_user} do
      conn = conn |> put_session(:to_be_removed, "value") |> LocalUserAuth.log_in_local_user(local_user)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, local_user: local_user} do
      conn = conn |> put_session(:local_user_return_to, "/hello") |> LocalUserAuth.log_in_local_user(local_user)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, local_user: local_user} do
      conn = conn |> fetch_cookies() |> LocalUserAuth.log_in_local_user(local_user, %{"remember_me" => "true"})
      assert get_session(conn, :local_user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :local_user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_local_user/1" do
    test "erases session and cookies", %{conn: conn, local_user: local_user} do
      local_user_token = Accounts.generate_local_user_session_token(local_user)

      conn =
        conn
        |> put_session(:local_user_token, local_user_token)
        |> put_req_cookie(@remember_me_cookie, local_user_token)
        |> fetch_cookies()
        |> LocalUserAuth.log_out_local_user()

      refute get_session(conn, :local_user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
      refute Accounts.get_local_user_by_session_token(local_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "local_users_sessions:abcdef-token"
      ActureWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> LocalUserAuth.log_out_local_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if local_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> LocalUserAuth.log_out_local_user()
      refute get_session(conn, :local_user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_local_user/2" do
    test "authenticates local_user from session", %{conn: conn, local_user: local_user} do
      local_user_token = Accounts.generate_local_user_session_token(local_user)
      conn = conn |> put_session(:local_user_token, local_user_token) |> LocalUserAuth.fetch_current_local_user([])
      assert conn.assigns.current_local_user.id == local_user.id
    end

    test "authenticates local_user from cookies", %{conn: conn, local_user: local_user} do
      logged_in_conn =
        conn |> fetch_cookies() |> LocalUserAuth.log_in_local_user(local_user, %{"remember_me" => "true"})

      local_user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> LocalUserAuth.fetch_current_local_user([])

      assert get_session(conn, :local_user_token) == local_user_token
      assert conn.assigns.current_local_user.id == local_user.id
    end

    test "does not authenticate if data is missing", %{conn: conn, local_user: local_user} do
      _ = Accounts.generate_local_user_session_token(local_user)
      conn = LocalUserAuth.fetch_current_local_user(conn, [])
      refute get_session(conn, :local_user_token)
      refute conn.assigns.current_local_user
    end
  end

  describe "redirect_if_local_user_is_authenticated/2" do
    test "redirects if local_user is authenticated", %{conn: conn, local_user: local_user} do
      conn = conn |> assign(:current_local_user, local_user) |> LocalUserAuth.redirect_if_local_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if local_user is not authenticated", %{conn: conn} do
      conn = LocalUserAuth.redirect_if_local_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_local_user/2" do
    test "redirects if local_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> LocalUserAuth.require_authenticated_local_user([])
      assert conn.halted
      assert redirected_to(conn) == Routes.local_user_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> LocalUserAuth.require_authenticated_local_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :local_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> LocalUserAuth.require_authenticated_local_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :local_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> LocalUserAuth.require_authenticated_local_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :local_user_return_to)
    end

    test "does not redirect if local_user is authenticated", %{conn: conn, local_user: local_user} do
      conn = conn |> assign(:current_local_user, local_user) |> LocalUserAuth.require_authenticated_local_user([])
      refute conn.halted
      refute conn.status
    end
  end
end
