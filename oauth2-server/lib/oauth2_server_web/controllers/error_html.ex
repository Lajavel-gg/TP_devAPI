defmodule Oauth2ServerWeb.ErrorHTML do
  @moduledoc """
  Error HTML rendering module.
  """

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
