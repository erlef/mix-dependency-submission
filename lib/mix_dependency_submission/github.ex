defmodule MixDependencySubmission.GitHub do
  @moduledoc """
  Convenience Methods to interact with the GitHub Actions environment.
  """

  @typedoc "git commit sha"
  @type sha() :: <<_::320>>

  @doc "Fetch the GitHub workspace directory."
  @spec fetch_workspace :: {:ok, Path.t()} | :error
  def fetch_workspace, do: System.fetch_env("GITHUB_WORKSPACE")

  @doc "Get the GitHub API URL."
  @spec get_api_url :: String.t()
  def get_api_url, do: System.get_env("GITHUB_API_URL", "https://api.github.com")

  @doc "Fetch the GitHub Repository. (owner/repo)"
  @spec fetch_repository :: {:ok, String.t()} | :error
  def fetch_repository, do: System.fetch_env("GITHUB_REPOSITORY")

  @doc "Fetch the GitHub Job ID."
  @spec fetch_job_id :: {:ok, String.t()} | :error
  def fetch_job_id, do: System.fetch_env("GITHUB_JOB")

  @doc "Fetch the GitHub Workflow Name."
  @spec fetch_workflow :: {:ok, String.t()} | :error
  def fetch_workflow, do: System.fetch_env("GITHUB_WORKFLOW")

  @doc "Fetch the git sha for which this action was triggered."
  @spec fetch_sha :: {:ok, sha()} | :error
  def fetch_sha, do: System.fetch_env("GITHUB_SHA")

  @doc "Fetch the git sha for which this action was triggered or the head commit of a pull request."
  @spec fetch_head_sha :: {:ok, sha()} | :error
  def fetch_head_sha do
    case fetch_pr_head_sha() do
      {:ok, sha} -> {:ok, sha}
      :error -> fetch_sha()
    end
  end

  # Note that pull_request_target is omitted here.
  # That event runs in the context of the base commit of the PR,
  # so the snapshot should not be associated with the head commit.

  @pr_events ~w[pull_request pull_request_comment pull_request_review pull_request_review_comment]

  @doc "Fetch the head commit sha of a pull request."
  @spec fetch_pr_head_sha :: {:ok, sha()} | :error
  def fetch_pr_head_sha do
    with {:ok, event} when event in @pr_events <- System.fetch_env("GITHUB_EVENT_NAME"),
         {:ok, event_path} <- System.fetch_env("GITHUB_EVENT_PATH") do
      event_details_json = File.read!(event_path)

      %{"pull_request" => %{"head" => %{"sha" => <<_binary::320>> = sha}}} =
        JSON.decode!(event_details_json)

      {:ok, sha}
    else
      {:ok, _other_event} -> :error
      :error -> :error
    end
  end

  @doc "Fetch the git ref for which this action was triggered."
  @spec fetch_ref :: {:ok, String.t()} | :error
  def fetch_ref, do: System.fetch_env("GITHUB_REF")

  @doc "Fetch GtiHub Actions token."
  @spec fetch_token :: {:ok, String.t()} | :error
  def fetch_token, do: System.fetch_env("GITHUB_TOKEN")

  @doc "Write output to the GitHub Actions output file."
  @spec write_output(key :: String.t(), value :: binary()) :: :ok | :error
  def write_output(key, value) do
    with {:ok, output} <- System.fetch_env("GITHUB_OUTPUT") do
      File.write!(output, "#{key}=#{value}\n", [:append])
    end
  end
end
