defmodule ActureWeb.Live.BrowserContext do
  alias __MODULE__
  defstruct ~w(timezone)a

  def new(fields) do
    %BrowserContext{
      timezone: Keyword.get(fields, :timezone, "UTC")
    }
  end
end
