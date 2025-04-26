defmodule MixDependencySubmission.CLI do
  @moduledoc """
  Handles parsing of CLI arguments using `Optimus`.

  Used to configure and validate inputs for submitting a dependency snapshot.
  """

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
  def parse!(argv) do
    cli_definition()
    |> Optimus.new!()
    |> Optimus.parse!(argv)
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
          parser: &parse_github_api_url/1,
          default: System.get_env("GITHUB_API_URL", "https://api.github.com")
        ],
        github_repository:
          optimus_options_with_env_default("GITHUB_REPOSITORY",
            value_name: "GITHUB_REPOSITORY",
            long: "--github-repository",
            help: ~S(GitHub repository name "owner/repository")
          ),
        github_job_id:
          optimus_options_with_env_default("GITHUB_JOB",
            value_name: "GITHUB_JOB",
            long: "--github-job-id",
            help: "GitHub Actions Job ID"
          ),
        github_workflow:
          optimus_options_with_env_default("GITHUB_WORKFLOW",
            value_name: "GITHUB_WORKFLOW",
            long: "--github-workflow",
            help: "GitHub Actions Workflow Name"
          ),
        sha:
          sha_option(
            value_name: "SHA",
            long: "--sha",
            help: "Current Git SHA"
          ),
        ref:
          optimus_options_with_env_default("GITHUB_REF",
            value_name: "REF",
            long: "--ref",
            help: "Current Git Ref"
          ),
        github_token:
          optimus_options_with_env_default("GITHUB_TOKEN",
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

  @spec parse_github_api_url(uri :: String.t()) :: Optimus.parser_result()
  defp parse_github_api_url(uri) do
    with {:ok, %URI{}} <- URI.new(uri) do
      uri
    end
  end

  @spec optimus_options_with_env_default(env :: String.t(), details :: Keyword.t()) :: Keyword.t()
  defp optimus_options_with_env_default(env, details) do
    case System.fetch_env(env) do
      {:ok, value} -> [default: value]
      :error -> [required: true]
    end ++ details
  end

  @spec sha_option(Keyword.t()) :: Keyword.t()
  defp sha_option(base_opts) do
    # If the GitHub event is a pull request, we need to use the head SHA of the PR
    # instead of the commit SHA of the workflow run.
    # This is because the workflow run is triggered by the base commit of the PR,
    # and we want to report the dependencies of the head commit.
    # See: https://github.com/github/dependency-submission-toolkit/blob/72f5e31325b5e1bcc91f1b12eb7abe68e75b2105/src/snapshot.ts#L36-L61
    case load_pr_head_sha() do
      {:ok, sha} ->
        Keyword.put(base_opts, :default, sha)

      :error ->
        # If we can't load the PR head SHA, we fall back to the default behavior
        # of using the GITHUB_SHA environment variable.
        optimus_options_with_env_default("GITHUB_SHA", base_opts)
    end
  end

  # Note that pull_request_target is omitted here.
  # That event runs in the context of the base commit of the PR,
  # so the snapshot should not be associated with the head commit.

  @pr_events ~w[pull_request pull_request_comment pull_request_review pull_request_review_comment]

  @spec load_pr_head_sha :: {:ok, <<_::320>>} | :error
  defp load_pr_head_sha do
    with {:ok, event} when event in @pr_events <- System.fetch_env("GITHUB_EVENT_NAME"),
         {:ok, event_path} <- System.fetch_env("GITHUB_EVENT_PATH") do
      event_details_json = File.read!(event_path)

      %{"pull_request" => %{"head" => %{"sha" => <<_binary::320>> = sha}}} =
        JSON.decode!(event_details_json)

      {:ok, sha}
    end
  end
end
