defmodule PhxAppWeb.PageController do
  use PhxAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
