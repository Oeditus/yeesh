defmodule PhxAppWeb.PageControllerTest do
  use PhxAppWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Yeesh Demo"
  end
end
