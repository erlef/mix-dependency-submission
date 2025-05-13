defmodule MixDependencySubmission.ApiClient do
  @moduledoc """
  Handles submission of the dependency snapshot to the GitHub Dependency Submission API.
  """

  alias MixDependencySubmission.Submission

  @doc """
  Submits a dependency snapshot to the GitHub API.

  Returns `{:ok, response}` if the submission was accepted, or
  `{:error, {:unexpected_response, response}}` for other HTTP status codes.

  ## Examples

      iex> submission = %MixDependencySubmission.Submission{
      ...>   version: 0,
      ...>   job: %MixDependencySubmission.Submission.Job{
      ...>     id: "job123",
      ...>     correlator: "workflow job123"
      ...>   },
      ...>   sha: String.duplicate("a", 40),
      ...>   ref: "refs/heads/main",
      ...>   detector: %MixDependencySubmission.Submission.Detector{
      ...>     name: "example",
      ...>     version: Version.parse!("1.0.0"),
      ...>     url: URI.parse("https://example.com")
      ...>   },
      ...>   scanned: DateTime.utc_now(),
      ...>   manifests: %{}
      ...> }
      ...>
      ...> {:ok, %Req.Response{} = response} =
      ...>   MixDependencySubmission.ApiClient.submit(
      ...>     submission,
      ...>     "https://api.github.com",
      ...>     "owner/repo",
      ...>     "ghp_exampletoken"
      ...>   )

  """
  @spec submit(
          submission :: Submission.t(),
          github_api_url :: String.t(),
          github_repository :: String.t(),
          github_token :: String.t()
        ) :: {:ok, Req.Response.t()} | {:error, {:unexpected_response, Req.Response.t()}}
  def submit(submission, github_api_url, github_repository, github_token) do
    client()
    |> Req.request!(
      base_url: github_api_url,
      json: submission,
      headers: [
        accept: "application/vnd.github+json",
        authorization: "Bearer #{github_token}",
        "x-github-api-version": "2022-11-28"
      ],
      url: "/repos/#{github_repository}/dependency-graph/snapshots"
    )
    |> case do
      %Req.Response{status: 201} = response -> {:ok, response}
      %Req.Response{} = response -> {:error, {:unexpected_response, response}}
    end
  end

  @spec client() :: Keyword.t()
  defp client do
    Keyword.merge(
      [connect_options: [transport_opts: [cacerts: :public_key.cacerts_get()]], method: :post],
      Application.get_env(:mix_dependency_submission, __MODULE__, [])
    )
  end
end
