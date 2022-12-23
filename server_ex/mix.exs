defmodule Topical.MixProject do
  use Mix.Project

  def project do
    [
      app: :topical,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
