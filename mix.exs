defmodule Cache.MixProject do
  use Mix.Project

  def project do
    [
      app: :eiger_cache,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],

      # Docs
      name: "Eiger Cache",
      source_url: "https://github.com/amilkr/eiger_cache",
      homepage_url: "https://github.com/amilkr/eiger_cache",
      docs: [
        main: "Cache",
        extras: ["README.md"]
      ]
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
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
