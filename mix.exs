defmodule VisionZeroDashboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :vision_zero_dashboard,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:geo, "~> 3.5"},
      {:topo, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:nimble_csv, "~> 1.1"}
    ]
  end
end
