defmodule MixDependencySubmission.CLI do
  @moduledoc """
  Handles parsing of CLI arguments using `Optimus`.

  Used to configure and validate inputs for submitting a dependency snapshot.
  """

  alias MixDependencySubmission.GitHub

  @app Mix.Project.config()[:app]
  @description Mix.Project.config()[:description]
  @version Mix.Project.config()[:version]

  @doc """
  Parses CLI arguments and returns the parsed result.

  Raises on invalid input.

  ## Examples

      iex> argv =
      ...>   ~w[--github-repository org/repo --github-job-id 123 --github-workflow build --sha sha --ref refs/heads/main --github-token ghp_xxx]
      ...>
      ...> result = MixDependencySubmission.CLI.parse!(argv)
      ...> result.options.github_repository
      "org/repo"

  """
  @spec parse!([String.t()]) :: Optimus.ParseResult.t()
  case Mix.env() do
    :test ->
      def parse!(argv) do
        cli_definition()
        |> Optimus.new!()
        |> Optimus.parse!(argv, &raise("Exit: #{&1}"))
      end

    _other ->
      def parse!(argv) do
        cli_definition()
        |> Optimus.new!()
        |> Optimus.parse!(argv)
      end
  end

  @spec cli_definition :: Optimus.spec()
  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  defp cli_definition do
    [
      name: Atom.to_string(@app),
      description: @description,
      version: @version,
      allow_unknown_args: false,
      options: [
        project_path: [
          value_name: "PROJECT_PATH",
          short: "-p",
          long: "--project-path",
          help: "Path to the project. (`directory` with `mix.exs`)",
          parser: &parse_directory/1,
          default: &File.cwd!/0
        ],
        paths_relative_to: [
          value_name: "PATHS_RELATIVE_TO",
          long: "--paths-relative-to",
          help: "Path to the root of the project.",
          parser: &parse_directory/1,
          default: System.get_env("GITHUB_WORKSPACE", File.cwd!())
        ],
        github_api_url: [
          value_name: "GITHUB_API_URL",
          long: "--github-api-url",
          help: "GitHub API URL",
          parser: &parse_uri/1,
          default: GitHub.get_api_url()
        ],
        github_repository:
          optimus_options_with_fun_default(&GitHub.fetch_repository/0,
            value_name: "GITHUB_REPOSITORY",
            long: "--github-repository",
            help: ~S(GitHub repository name "owner/repository")
          ),
        github_job_id:
          optimus_options_with_fun_default(&GitHub.fetch_job_id/0,
            value_name: "GITHUB_JOB",
            long: "--github-job-id",
            help: "GitHub Actions Job ID"
          ),
        github_workflow:
          optimus_options_with_fun_default(&GitHub.fetch_workflow/0,
            value_name: "GITHUB_WORKFLOW",
            long: "--github-workflow",
            help: "GitHub Actions Workflow Name"
          ),
        sha:
          optimus_options_with_fun_default(&GitHub.fetch_head_sha/0,
            value_name: "SHA",
            long: "--sha",
            help: "Current Git SHA"
          ),
        ref:
          optimus_options_with_fun_default(&GitHub.fetch_ref/0,
            value_name: "REF",
            long: "--ref",
            help: "Current Git Ref"
          ),
        github_token:
          optimus_options_with_fun_default(&GitHub.fetch_token/0,
            value_name: "GITHUB_TOKEN",
            long: "--github-token",
            help: "GitHub Token"
          ),
        ignore: [
          value_name: "IGNORE",
          long: "--ignore",
          help: "Directories to Ignore",
          parser: &parse_directory/1,
          multiple: true
        ]
      ],
      flags: [
        install_deps: [
          short: "-i",
          long: "--install-deps",
          help: "Wether to install the dependencies before reporting.",
          multiple: false
        ]
      ]
    ]
  end

  @spec parse_directory(path :: String.t()) :: Optimus.parser_result()
  defp parse_directory(path) do
    if File.dir?(path) do
      {:ok, Path.absname(path)}
    else
      {:error, "invalid path"}
    end
  end

  @spec parse_uri(uri :: String.t()) :: Optimus.parser_result()
  defp parse_uri(uri) do
    with {:ok, %URI{}} <- URI.new(uri) do
      {:ok, uri}
    end
  end

  @spec optimus_options_with_fun_default(
          fetch_fun :: (-> {:ok, value} | :error),
          details :: Keyword.t()
        ) :: Keyword.t()
        when value: term()
  defp optimus_options_with_fun_default(fetch_fun, details) when is_function(fetch_fun, 0) do
    case fetch_fun.() do
      {:ok, value} -> [default: value]
      :error -> [required: true]
    end ++ details
  end
end
