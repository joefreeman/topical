defmodule Todo.MixProject do
  use Mix.Project

  def project do
    [
      app: :todo,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Todo.Application, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.9"},
      {:plug, "~> 1.15"},
      {:bandit, "~> 1.1"},
      {:websock_adapter, "~> 0.5"},
      {:topical, path: "../../server_ex"}
    ]
  end
end
