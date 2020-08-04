defmodule Exaop.MixProject do
  use Mix.Project

  def project do
    [
      app: :exaop,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:espec, "~> 1.8.2", only: :test}
    ]
  end

  defp package do
    [
      name: :exaop,
      maintainers: ["Ming Qu"],
      licenses: ["MIT"],
      links: %{}
    ]
  end
end
