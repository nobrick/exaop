defmodule Exaop.MixProject do
  use Mix.Project

  def project do
    [
      app: :exaop,
      version: "0.1.0",
      elixir: "~> 1.7",
      description: description(),
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      main: "Exaop",
      name: "Exaop",
      source_url: source_url(),
      docs: [
        extras: [
          "README.md"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "A minimal library for aspect-oriented programming."
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:espec, "~> 1.8.2", only: :test}
    ]
  end

  defp package do
    [
      name: :exaop,
      maintainers: ["Ming Qu"],
      licenses: ["MIT"],
      links: %{"GitHub" => source_url()}
    ]
  end

  defp source_url do
    "https://github.com/nobrick/exaop"
  end
end
