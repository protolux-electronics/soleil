defmodule Soleil.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/protolux-electronics/soleil"
  @homepage_url "https://protolux.io/projects/soleil"

  def project do
    [
      app: :soleil,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: @source_url,
      homepage_url: @homepage_url,
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Drivers and modules to support the Soleil low-power solar battery charger board for Raspberry Pi"
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_i2c, "~> 1.0 or ~> 0.3.6 or ~> 2.0"},
      {:nerves_time, "~> 0.4.0"},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "introduction",
      extra_section: "GUIDES",
      extras: [
        "guides/introduction.md",
        "guides/getting_started.md",
        "guides/technical_overview.md"
      ]
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "LICENSE",
        "mix.exs",
        "README.md"
      ],
      licenses: ["MIT"],
      links: %{
        "Home page" => "https://protolux.io/soleil",
        "GitHub" => @source_url
      }
    ]
  end
end
