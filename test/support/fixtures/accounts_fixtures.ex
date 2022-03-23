defmodule Acture.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Acture.Accounts` context.
  """

  def unique_local_user_email, do: "local_user#{System.unique_integer()}@example.com"
  def valid_local_user_password, do: "hello world!"

  def valid_local_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_local_user_email(),
      password: valid_local_user_password()
    })
  end

  def local_user_fixture(attrs \\ %{}) do
    {:ok, local_user} =
      attrs
      |> valid_local_user_attributes()
      |> Acture.Accounts.register_local_user()

    local_user
  end

  def extract_local_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
