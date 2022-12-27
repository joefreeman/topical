defmodule Topical.MixProject do
  use Mix.Project

  def project do
    [
      app: :topical,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:jason, "~> 1.4"}
    ]
  end

  defp description do
    """
    Simple server-maintained state synchronisation.
    """
  end

  defp package do
    [
      maintainers: ["Joe Freeman"],
      licenses: ["Apache-2.0"],
      links: %{GitHub: "https://github.com/joefreeman/topical"}
    ]
  end
end
