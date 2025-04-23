defmodule MixDependencySubmission.CLI.Submit do
  @moduledoc """
  Handles the CLI submit command for Mix Dependency Submission.

  This module parses CLI arguments, builds the dependency submission payload,
  and sends it to the GitHub Dependency Submission API. It logs relevant details
  about the submission process and handles success or failure scenarios
  accordingly.
  """

  alias MixDependencySubmission.ApiClient
  alias MixDependencySubmission.CLI

  require Logger

  @doc """
  Parses command-line arguments and submits the dependency snapshot to the
  GitHub API.

  This function is intended to be called from the CLI. It:

  - Parses CLI arguments using `Optimus`.
  - Generates a dependency submission using
    `MixDependencySubmission.submission/1`.
  - Logs the resulting submission in pretty-printed JSON.
  - Sends the submission to GitHub using
    `MixDependencySubmission.ApiClient.submit/4`.
  - Logs the response or error and exits with code 0 or 1 accordingly.

  ## Parameters

    - `argv`: A list of command-line argument strings.

  ## Behavior

  This function does not return. It will halt or stop the system depending on
  the outcome of the submission.

  ## Examples

      iex> MixDependencySubmission.CLI.Submit.run([
      ...>   "--project-path",
      ...>   ".",
      ...>   "--github-repository",
      ...>   "org/repo"
      ...> ])

  """
  @spec run(argv :: [String.t()]) :: no_return()
  def run(argv) do
    %Optimus.ParseResult{
      options: %{
        project_path: project_path,
        paths_relative_to: paths_relative_to,
        github_api_url: github_api_url,
        github_repository: github_repository,
        github_token: github_token,
        github_job_id: github_job_id,
        github_workflow: github_workflow,
        sha: sha,
        ref: ref,
        ignore: ignore
      },
      flags: %{
        install_deps: install_deps?
      }
    } = CLI.parse!(argv)

    submission =
      MixDependencySubmission.submission(
        github_job_id: github_job_id,
        github_workflow: github_workflow,
        sha: sha,
        ref: ref,
        project_path: project_path,
        paths_relative_to: paths_relative_to,
        install_deps?: install_deps?,
        ignore: ignore
      )

    Logger.info("Calculated Submission: #{JSON.encode!(submission, pretty: true)}")

    submission
    |> ApiClient.submit(github_api_url, github_repository, github_token)
    |> case do
      {:ok, %Req.Response{body: body}} ->
        Logger.info("Successfully submitted submission")
        Logger.debug("Success Response: #{inspect(body, pretty: true)}")

        System.halt(0)

      {:error, {:unexpected_response, response}} ->
        Logger.error("Unexpected response: #{inspect(response, pretty: true)}")
        System.stop(1)
    end
  end
end
