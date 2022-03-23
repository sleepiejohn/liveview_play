defmodule Acture.AccountsTest do
  use Acture.DataCase

  alias Acture.Accounts

  import Acture.AccountsFixtures
  alias Acture.Accounts.{LocalUser, LocalUserToken}

  describe "get_local_user_by_email/1" do
    test "does not return the local_user if the email does not exist" do
      refute Accounts.get_local_user_by_email("unknown@example.com")
    end

    test "returns the local_user if the email exists" do
      %{id: id} = local_user = local_user_fixture()
      assert %LocalUser{id: ^id} = Accounts.get_local_user_by_email(local_user.email)
    end
  end

  describe "get_local_user_by_email_and_password/2" do
    test "does not return the local_user if the email does not exist" do
      refute Accounts.get_local_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the local_user if the password is not valid" do
      local_user = local_user_fixture()
      refute Accounts.get_local_user_by_email_and_password(local_user.email, "invalid")
    end

    test "returns the local_user if the email and password are valid" do
      %{id: id} = local_user = local_user_fixture()

      assert %LocalUser{id: ^id} =
               Accounts.get_local_user_by_email_and_password(local_user.email, valid_local_user_password())
    end
  end

  describe "get_local_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_local_user!(-1)
      end
    end

    test "returns the local_user with the given id" do
      %{id: id} = local_user = local_user_fixture()
      assert %LocalUser{id: ^id} = Accounts.get_local_user!(local_user.id)
    end
  end

  describe "register_local_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_local_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_local_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_local_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = local_user_fixture()
      {:error, changeset} = Accounts.register_local_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_local_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers local_users with a hashed password" do
      email = unique_local_user_email()
      {:ok, local_user} = Accounts.register_local_user(valid_local_user_attributes(email: email))
      assert local_user.email == email
      assert is_binary(local_user.hashed_password)
      assert is_nil(local_user.confirmed_at)
      assert is_nil(local_user.password)
    end
  end

  describe "change_local_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_local_user_registration(%LocalUser{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_local_user_email()
      password = valid_local_user_password()

      changeset =
        Accounts.change_local_user_registration(
          %LocalUser{},
          valid_local_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_local_user_email/2" do
    test "returns a local_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_local_user_email(%LocalUser{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_local_user_email/3" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "requires email to change", %{local_user: local_user} do
      {:error, changeset} = Accounts.apply_local_user_email(local_user, valid_local_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{local_user: local_user} do
      {:error, changeset} =
        Accounts.apply_local_user_email(local_user, valid_local_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{local_user: local_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_local_user_email(local_user, valid_local_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{local_user: local_user} do
      %{email: email} = local_user_fixture()

      {:error, changeset} =
        Accounts.apply_local_user_email(local_user, valid_local_user_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{local_user: local_user} do
      {:error, changeset} =
        Accounts.apply_local_user_email(local_user, "invalid", %{email: unique_local_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{local_user: local_user} do
      email = unique_local_user_email()
      {:ok, local_user} = Accounts.apply_local_user_email(local_user, valid_local_user_password(), %{email: email})
      assert local_user.email == email
      assert Accounts.get_local_user!(local_user.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "sends token through notification", %{local_user: local_user} do
      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_update_email_instructions(local_user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert local_user_token = Repo.get_by(LocalUserToken, token: :crypto.hash(:sha256, token))
      assert local_user_token.local_user_id == local_user.id
      assert local_user_token.sent_to == local_user.email
      assert local_user_token.context == "change:current@example.com"
    end
  end

  describe "update_local_user_email/2" do
    setup do
      local_user = local_user_fixture()
      email = unique_local_user_email()

      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{local_user | email: email}, local_user.email, url)
        end)

      %{local_user: local_user, token: token, email: email}
    end

    test "updates the email with a valid token", %{local_user: local_user, token: token, email: email} do
      assert Accounts.update_local_user_email(local_user, token) == :ok
      changed_local_user = Repo.get!(LocalUser, local_user.id)
      assert changed_local_user.email != local_user.email
      assert changed_local_user.email == email
      assert changed_local_user.confirmed_at
      assert changed_local_user.confirmed_at != local_user.confirmed_at
      refute Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not update email with invalid token", %{local_user: local_user} do
      assert Accounts.update_local_user_email(local_user, "oops") == :error
      assert Repo.get!(LocalUser, local_user.id).email == local_user.email
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not update email if local_user email changed", %{local_user: local_user, token: token} do
      assert Accounts.update_local_user_email(%{local_user | email: "current@example.com"}, token) == :error
      assert Repo.get!(LocalUser, local_user.id).email == local_user.email
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not update email if token expired", %{local_user: local_user, token: token} do
      {1, nil} = Repo.update_all(LocalUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_local_user_email(local_user, token) == :error
      assert Repo.get!(LocalUser, local_user.id).email == local_user.email
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end
  end

  describe "change_local_user_password/2" do
    test "returns a local_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_local_user_password(%LocalUser{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_local_user_password(%LocalUser{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_local_user_password/3" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "validates password", %{local_user: local_user} do
      {:error, changeset} =
        Accounts.update_local_user_password(local_user, valid_local_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{local_user: local_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_local_user_password(local_user, valid_local_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{local_user: local_user} do
      {:error, changeset} =
        Accounts.update_local_user_password(local_user, "invalid", %{password: valid_local_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{local_user: local_user} do
      {:ok, local_user} =
        Accounts.update_local_user_password(local_user, valid_local_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(local_user.password)
      assert Accounts.get_local_user_by_email_and_password(local_user.email, "new valid password")
    end

    test "deletes all tokens for the given local_user", %{local_user: local_user} do
      _ = Accounts.generate_local_user_session_token(local_user)

      {:ok, _} =
        Accounts.update_local_user_password(local_user, valid_local_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end
  end

  describe "generate_local_user_session_token/1" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "generates a token", %{local_user: local_user} do
      token = Accounts.generate_local_user_session_token(local_user)
      assert local_user_token = Repo.get_by(LocalUserToken, token: token)
      assert local_user_token.context == "session"

      # Creating the same token for another local_user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%LocalUserToken{
          token: local_user_token.token,
          local_user_id: local_user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_local_user_by_session_token/1" do
    setup do
      local_user = local_user_fixture()
      token = Accounts.generate_local_user_session_token(local_user)
      %{local_user: local_user, token: token}
    end

    test "returns local_user by token", %{local_user: local_user, token: token} do
      assert session_local_user = Accounts.get_local_user_by_session_token(token)
      assert session_local_user.id == local_user.id
    end

    test "does not return local_user for invalid token" do
      refute Accounts.get_local_user_by_session_token("oops")
    end

    test "does not return local_user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(LocalUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_local_user_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      local_user = local_user_fixture()
      token = Accounts.generate_local_user_session_token(local_user)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_local_user_by_session_token(token)
    end
  end

  describe "deliver_local_user_confirmation_instructions/2" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "sends token through notification", %{local_user: local_user} do
      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_local_user_confirmation_instructions(local_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert local_user_token = Repo.get_by(LocalUserToken, token: :crypto.hash(:sha256, token))
      assert local_user_token.local_user_id == local_user.id
      assert local_user_token.sent_to == local_user.email
      assert local_user_token.context == "confirm"
    end
  end

  describe "confirm_local_user/1" do
    setup do
      local_user = local_user_fixture()

      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_local_user_confirmation_instructions(local_user, url)
        end)

      %{local_user: local_user, token: token}
    end

    test "confirms the email with a valid token", %{local_user: local_user, token: token} do
      assert {:ok, confirmed_local_user} = Accounts.confirm_local_user(token)
      assert confirmed_local_user.confirmed_at
      assert confirmed_local_user.confirmed_at != local_user.confirmed_at
      assert Repo.get!(LocalUser, local_user.id).confirmed_at
      refute Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not confirm with invalid token", %{local_user: local_user} do
      assert Accounts.confirm_local_user("oops") == :error
      refute Repo.get!(LocalUser, local_user.id).confirmed_at
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not confirm email if token expired", %{local_user: local_user, token: token} do
      {1, nil} = Repo.update_all(LocalUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_local_user(token) == :error
      refute Repo.get!(LocalUser, local_user.id).confirmed_at
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end
  end

  describe "deliver_local_user_reset_password_instructions/2" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "sends token through notification", %{local_user: local_user} do
      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_local_user_reset_password_instructions(local_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert local_user_token = Repo.get_by(LocalUserToken, token: :crypto.hash(:sha256, token))
      assert local_user_token.local_user_id == local_user.id
      assert local_user_token.sent_to == local_user.email
      assert local_user_token.context == "reset_password"
    end
  end

  describe "get_local_user_by_reset_password_token/1" do
    setup do
      local_user = local_user_fixture()

      token =
        extract_local_user_token(fn url ->
          Accounts.deliver_local_user_reset_password_instructions(local_user, url)
        end)

      %{local_user: local_user, token: token}
    end

    test "returns the local_user with valid token", %{local_user: %{id: id}, token: token} do
      assert %LocalUser{id: ^id} = Accounts.get_local_user_by_reset_password_token(token)
      assert Repo.get_by(LocalUserToken, local_user_id: id)
    end

    test "does not return the local_user with invalid token", %{local_user: local_user} do
      refute Accounts.get_local_user_by_reset_password_token("oops")
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end

    test "does not return the local_user if token expired", %{local_user: local_user, token: token} do
      {1, nil} = Repo.update_all(LocalUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_local_user_by_reset_password_token(token)
      assert Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end
  end

  describe "reset_local_user_password/2" do
    setup do
      %{local_user: local_user_fixture()}
    end

    test "validates password", %{local_user: local_user} do
      {:error, changeset} =
        Accounts.reset_local_user_password(local_user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{local_user: local_user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_local_user_password(local_user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{local_user: local_user} do
      {:ok, updated_local_user} = Accounts.reset_local_user_password(local_user, %{password: "new valid password"})
      assert is_nil(updated_local_user.password)
      assert Accounts.get_local_user_by_email_and_password(local_user.email, "new valid password")
    end

    test "deletes all tokens for the given local_user", %{local_user: local_user} do
      _ = Accounts.generate_local_user_session_token(local_user)
      {:ok, _} = Accounts.reset_local_user_password(local_user, %{password: "new valid password"})
      refute Repo.get_by(LocalUserToken, local_user_id: local_user.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%LocalUser{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
