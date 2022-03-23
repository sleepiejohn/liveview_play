defmodule Acture.Accounts.LocalUserToken do
  use Ecto.Schema
  import Ecto.Query

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 60

  schema "local_users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :local_user, Acture.Accounts.LocalUser

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual local_user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session_token(local_user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %Acture.Accounts.LocalUserToken{token: token, context: "session", local_user_id: local_user.id}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the local_user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) do
    query =
      from token in token_and_context_query(token, "session"),
        join: local_user in assoc(token, :local_user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: local_user

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the local_user's email.

  The non-hashed token is sent to the local_user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_email_token(local_user, context) do
    build_hashed_token(local_user, context, local_user.email)
  end

  defp build_hashed_token(local_user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %Acture.Accounts.LocalUserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       local_user_id: local_user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the local_user found by the token, if any.

  The given token is valid if it matches its hashed counterpart in the
  database and the user email has not changed. This function also checks
  if the token is being used within a certain period, depending on the
  context. The default contexts supported by this function are either
  "confirm", for account confirmation emails, and "reset_password",
  for resetting the password. For verifying requests to change the email,
  see `verify_change_email_token_query/2`.
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: local_user in assoc(token, :local_user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == local_user.email,
            select: local_user

        {:ok, query}

      :error ->
        :error
    end
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the local_user found by the token, if any.

  This is used to validate requests to change the local_user
  email. It is different from `verify_email_token_query/2` precisely because
  `verify_email_token_query/2` validates the email has not changed, which is
  the starting point by this function.

  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".
  """
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns the token struct for the given token value and context.
  """
  def token_and_context_query(token, context) do
    from Acture.Accounts.LocalUserToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Gets all tokens for the given local_user for the given contexts.
  """
  def local_user_and_contexts_query(local_user, :all) do
    from t in Acture.Accounts.LocalUserToken, where: t.local_user_id == ^local_user.id
  end

  def local_user_and_contexts_query(local_user, [_ | _] = contexts) do
    from t in Acture.Accounts.LocalUserToken, where: t.local_user_id == ^local_user.id and t.context in ^contexts
  end
end
