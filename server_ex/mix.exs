defmodule Topical.MixProject do
  use Mix.Project

  def project do
    [
      app: :topical,
      version: "0.2.3",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
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
      {:jason, "~> 1.4"},
      {:cowboy, "~> 2.9", optional: true}
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

  defp docs do
    [
      main: "introduction",
      extras: [
        "docs/introduction.md",
        "docs/getting-started.md",
        "docs/websocket-adapter.md",
        "docs/javascript-client.md"
      ]
    ]
  end
end
