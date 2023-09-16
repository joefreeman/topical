defmodule Cache.MixProject do
  use Mix.Project

  def project do
    [
      app: :cache,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Cache.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.9"},
      {:topical, path: "../../server_ex"}
    ]
  end
end
