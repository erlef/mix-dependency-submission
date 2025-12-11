# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule MixDependencySubmission.MixProject do
  use Mix.Project

  @version "1.3.0-beta.1"
  @source_url "https://github.com/erlef/mix-dependency-submission"
  @description "Calculates dependencies for Mix and submits the list to the GitHub Dependency Submission API"

  def project do
    [
      app: :mix_dependency_submission,
      version: @version,
      elixir: "1.19.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      archives: archives(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [
        tool: ExCoveralls,
        ignore_modules: [MixDependencySubmission.CLI, MixDependencySubmission.CLI.Submit]
      ],
      description: @description,
      dialyzer: [list_unused_filters: true],
      source_url: @source_url,
      releases: releases(),
      test_ignore_filters: [~r|test/fixtures/.+|]
    ]
  end

  def cli do
    [
      preferred_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "coveralls.xml": :test
      ]
    ]
  end

  def application do
    [
      mod: {MixDependencySubmission.Application, []},
      extra_applications: [:logger, :mix]
    ]
  end

  def releases do
    [
      mix_dependency_submission: [
        applications: [hex: :load],
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            Linux_X64: [os: :linux, cpu: :x86_64],
            Linux_ARM64: [os: :linux, cpu: :aarch64],
            macOS_X64: [os: :darwin, cpu: :x86_64],
            macOS_ARM64: [os: :darwin, cpu: :aarch64],
            Windows_X64: [os: :windows, cpu: :x86_64]
            # Not currently supported by Burrito
            # Windows_ARM64: [os: :windows, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end

  defp docs do
    [
      source_url: @source_url,
      source_ref: "v" <> @version,
      main: "readme",
      extras: ["README.md"],
      nest_modules_by_prefix: [MixDependencySubmission]
    ]
  end

  defp deps do
    # styler:sort
    [
      {:burrito, "~> 1.0"},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:doctest_formatter, "~> 0.4.0", runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.5", only: [:test], runtime: false},
      {:jason, "~> 1.4"},
      {:optimus, "~> 0.5.1"},
      {:plug, "~> 1.0", only: [:test]},
      {:purl, "~> 0.3.0"},
      {:req, "~> 0.5.6"},
      # TODO: Update to stable release when available
      {:sbom, "~> 0.8.0-beta"},
      {:styler, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp archives do
    [
      {:hex, "~> 2.3"}
    ]
  end
end
