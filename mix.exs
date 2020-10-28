defmodule OtelSandbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :otel_sandbox,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OtelSandbox.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:opentelemetry, "~> 0.4.0"},
      {:opentelemetry_api, "~> 0.3.2"},
      {:opentelemetry_honeycomb, "~> 0.3.0-rc.0"},
      {:poison, ">= 1.5.0"},
      {:hackney, ">= 1.11.0"}
    ]
  end
end
