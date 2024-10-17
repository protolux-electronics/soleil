defmodule Soleil.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/protolux-electronics/soleil"

  def project do
    [
      app: :soleil,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: @source_url
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
      {:ex_doc, "~> 0.19", only: :docs, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end
end
