defmodule PregelEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :pregel_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "PregelEx - A distributed graph processing framework in Elixir",
      package: package(),
      name: "PregelEx",
      source_url: "https://github.com/Gearhartlove/pregel_ex"
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      organization: "Swords to Software",
      links: %{"Github" => "https://github.com/Gearhartlove/pregel_ex"}
    }
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PregelEx.Application, []},
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end
end
