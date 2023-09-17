defmodule EventSourcing.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_sourcing,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EventSourcing.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.9"},
      {:topical, path: "../../server_ex"}
    ]
  end
end
