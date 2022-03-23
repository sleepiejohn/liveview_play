defmodule ActureWeb.Router do
  use ActureWeb, :router

  import ActureWeb.LocalUserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ActureWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_local_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ActureWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", ActureWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ActureWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ActureWeb do
    pipe_through [:browser, :redirect_if_local_user_is_authenticated]

    get "/auth/register", LocalUserRegistrationController, :new
    post "/auth/register", LocalUserRegistrationController, :create
    get "/auth/log_in", LocalUserSessionController, :new
    post "/auth/log_in", LocalUserSessionController, :create
    get "/auth/reset_password", LocalUserResetPasswordController, :new
    post "/auth/reset_password", LocalUserResetPasswordController, :create
    get "/auth/reset_password/:token", LocalUserResetPasswordController, :edit
    put "/auth/reset_password/:token", LocalUserResetPasswordController, :update
  end

  scope "/", ActureWeb do
    pipe_through [:browser, :require_authenticated_local_user]

    get "/local_users/settings", LocalUserSettingsController, :edit
    put "/local_users/settings", LocalUserSettingsController, :update
    get "/local_users/settings/confirm_email/:token", LocalUserSettingsController, :confirm_email
  end

  scope "/", ActureWeb do
    pipe_through [:browser]

    delete "/auth/log_out", LocalUserSessionController, :delete
    get "/auth/confirm", LocalUserConfirmationController, :new
    post "/auth/confirm", LocalUserConfirmationController, :create
    get "/auth/confirm/:token", LocalUserConfirmationController, :edit
    post "/auth/confirm/:token", LocalUserConfirmationController, :update
  end
end
