defmodule ActureWeb.Live.InitAssings do
  @moduledoc """
  Module with callbacks to when the socket is mounted, used to fetch parameters
  from the client-side
  """

  import Phoenix.LiveView
  alias ActureWeb.Live.BrowserContext

  def on_mount(:private, _params, _session, socket) do
    timezone = get_connect_params(socket)["timezone"] || "UTC"

    socket
    |> assign(:browser_context, BrowserContext.new(timezone: timezone))
    |> then(&{:cont, &1})
  end
end
