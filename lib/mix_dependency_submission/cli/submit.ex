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
  alias MixDependencySubmission.GitHub

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
      # Exit Code
      0

  """
  @spec run(argv :: [String.t()]) :: non_neg_integer()
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

    submission_json = JSON.encode!(submission)

    submission_path =
      Path.join(System.tmp_dir!(), "submission-#{:erlang.crc32(submission_json)}.json")

    File.write!(submission_path, submission_json)

    Logger.info("Calculated Submission, written to: #{submission_path}")

    GitHub.write_output("submission-json-path", submission_path)

    submission
    |> ApiClient.submit(github_api_url, github_repository, github_token)
    |> case do
      {:ok, %Req.Response{body: body, status: 201}} ->
        report_result(body, github_api_url, github_repository)

      {:error, {:unexpected_response, response}} ->
        Logger.error("Unexpected response: #{inspect(response, pretty: true)}")

        2
    end
  end

  defp report_result(body, github_api_url, github_repository)

  defp report_result(
         %{"id" => submission_id, "message" => message, "result" => result} = body,
         github_api_url,
         github_repository
       )
       when result in ~w[SUCCESS ACCEPTED] do
    Logger.info("Successfully submitted submission: #{result}: #{message}")
    Logger.debug("Success Response: #{inspect(body, pretty: true)}")

    GitHub.write_output("snapshot-id", submission_id)

    GitHub.write_output(
      "snapshot-api-url",
      github_api_url <> "/repos/#{github_repository}/dependency-graph/snapshots/#{submission_id}"
    )

    0
  end

  @spec report_result(
          body :: %{String.t() => term()},
          github_api_url :: String.t(),
          github_repository :: String.t()
        ) :: non_neg_integer()
  defp report_result(
         %{"id" => submission_id, "message" => message, "result" => "INVALID"} = body,
         github_api_url,
         github_repository
       ) do
    Logger.error("Invalid submission: #{message}")
    Logger.debug("Invalid Response: #{inspect(body, pretty: true)}")

    GitHub.write_output("snapshot-id", submission_id)

    GitHub.write_output(
      "snapshot-api-url",
      github_api_url <> "/repos/#{github_repository}/dependency-graph/snapshots/#{submission_id}"
    )

    1
  end
end
