defmodule Acture.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Acture.Repo

  alias Acture.Accounts.{LocalUser, LocalUserToken, LocalUserNotifier}

  ## Database getters

  @doc """
  Gets a local_user by email.

  ## Examples

      iex> get_local_user_by_email("foo@example.com")
      %LocalUser{}

      iex> get_local_user_by_email("unknown@example.com")
      nil

  """
  def get_local_user_by_email(email) when is_binary(email) do
    Repo.get_by(LocalUser, email: email)
  end

  @doc """
  Gets a local_user by email and password.

  ## Examples

      iex> get_local_user_by_email_and_password("foo@example.com", "correct_password")
      %LocalUser{}

      iex> get_local_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_local_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    local_user = Repo.get_by(LocalUser, email: email)
    if LocalUser.valid_password?(local_user, password), do: local_user
  end

  @doc """
  Gets a single local_user.

  Raises `Ecto.NoResultsError` if the LocalUser does not exist.

  ## Examples

      iex> get_local_user!(123)
      %LocalUser{}

      iex> get_local_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_local_user!(id), do: Repo.get!(LocalUser, id)

  ## Local user registration

  @doc """
  Registers a local_user.

  ## Examples

      iex> register_local_user(%{field: value})
      {:ok, %LocalUser{}}

      iex> register_local_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_local_user(attrs) do
    %LocalUser{}
    |> LocalUser.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking local_user changes.

  ## Examples

      iex> change_local_user_registration(local_user)
      %Ecto.Changeset{data: %LocalUser{}}

  """
  def change_local_user_registration(%LocalUser{} = local_user, attrs \\ %{}) do
    LocalUser.registration_changeset(local_user, attrs, hash_password: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the local_user email.

  ## Examples

      iex> change_local_user_email(local_user)
      %Ecto.Changeset{data: %LocalUser{}}

  """
  def change_local_user_email(local_user, attrs \\ %{}) do
    LocalUser.email_changeset(local_user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_local_user_email(local_user, "valid password", %{email: ...})
      {:ok, %LocalUser{}}

      iex> apply_local_user_email(local_user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_local_user_email(local_user, password, attrs) do
    local_user
    |> LocalUser.email_changeset(attrs)
    |> LocalUser.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the local_user email using the given token.

  If the token matches, the local_user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_local_user_email(local_user, token) do
    context = "change:#{local_user.email}"

    with {:ok, query} <- LocalUserToken.verify_change_email_token_query(token, context),
         %LocalUserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(local_user_email_multi(local_user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp local_user_email_multi(local_user, email, context) do
    changeset =
      local_user
      |> LocalUser.email_changeset(%{email: email})
      |> LocalUser.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:local_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, LocalUserToken.local_user_and_contexts_query(local_user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given local_user.

  ## Examples

      iex> deliver_update_email_instructions(local_user, current_email, &Routes.local_user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%LocalUser{} = local_user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, local_user_token} = LocalUserToken.build_email_token(local_user, "change:#{current_email}")

    Repo.insert!(local_user_token)
    LocalUserNotifier.deliver_update_email_instructions(local_user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the local_user password.

  ## Examples

      iex> change_local_user_password(local_user)
      %Ecto.Changeset{data: %LocalUser{}}

  """
  def change_local_user_password(local_user, attrs \\ %{}) do
    LocalUser.password_changeset(local_user, attrs, hash_password: false)
  end

  @doc """
  Updates the local_user password.

  ## Examples

      iex> update_local_user_password(local_user, "valid password", %{password: ...})
      {:ok, %LocalUser{}}

      iex> update_local_user_password(local_user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_local_user_password(local_user, password, attrs) do
    changeset =
      local_user
      |> LocalUser.password_changeset(attrs)
      |> LocalUser.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:local_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, LocalUserToken.local_user_and_contexts_query(local_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{local_user: local_user}} -> {:ok, local_user}
      {:error, :local_user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_local_user_session_token(local_user) do
    {token, local_user_token} = LocalUserToken.build_session_token(local_user)
    Repo.insert!(local_user_token)
    token
  end

  @doc """
  Gets the local_user with the given signed token.
  """
  def get_local_user_by_session_token(token) do
    {:ok, query} = LocalUserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(LocalUserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given local_user.

  ## Examples

      iex> deliver_local_user_confirmation_instructions(local_user, &Routes.local_user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_local_user_confirmation_instructions(confirmed_local_user, &Routes.local_user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_local_user_confirmation_instructions(%LocalUser{} = local_user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if local_user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, local_user_token} = LocalUserToken.build_email_token(local_user, "confirm")
      Repo.insert!(local_user_token)
      LocalUserNotifier.deliver_confirmation_instructions(local_user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a local_user by the given token.

  If the token matches, the local_user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_local_user(token) do
    with {:ok, query} <- LocalUserToken.verify_email_token_query(token, "confirm"),
         %LocalUser{} = local_user <- Repo.one(query),
         {:ok, %{local_user: local_user}} <- Repo.transaction(confirm_local_user_multi(local_user)) do
      {:ok, local_user}
    else
      _ -> :error
    end
  end

  defp confirm_local_user_multi(local_user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:local_user, LocalUser.confirm_changeset(local_user))
    |> Ecto.Multi.delete_all(:tokens, LocalUserToken.local_user_and_contexts_query(local_user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given local_user.

  ## Examples

      iex> deliver_local_user_reset_password_instructions(local_user, &Routes.local_user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_local_user_reset_password_instructions(%LocalUser{} = local_user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, local_user_token} = LocalUserToken.build_email_token(local_user, "reset_password")
    Repo.insert!(local_user_token)
    LocalUserNotifier.deliver_reset_password_instructions(local_user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the local_user by reset password token.

  ## Examples

      iex> get_local_user_by_reset_password_token("validtoken")
      %LocalUser{}

      iex> get_local_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_local_user_by_reset_password_token(token) do
    with {:ok, query} <- LocalUserToken.verify_email_token_query(token, "reset_password"),
         %LocalUser{} = local_user <- Repo.one(query) do
      local_user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the local_user password.

  ## Examples

      iex> reset_local_user_password(local_user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %LocalUser{}}

      iex> reset_local_user_password(local_user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_local_user_password(local_user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:local_user, LocalUser.password_changeset(local_user, attrs))
    |> Ecto.Multi.delete_all(:tokens, LocalUserToken.local_user_and_contexts_query(local_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{local_user: local_user}} -> {:ok, local_user}
      {:error, :local_user, changeset, _} -> {:error, changeset}
    end
  end
end
