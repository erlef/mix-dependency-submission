defmodule MixDependencySubmission.Submission do
  @moduledoc """
  Represents the top-level dependency submission payload.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  alias MixDependencySubmission.Submission.Detector
  alias MixDependencySubmission.Submission.Job
  alias MixDependencySubmission.Submission.Manifest

  @type manifests() :: %{String.t() => Manifest.t()}
  @type t :: %__MODULE__{
          version: non_neg_integer(),
          job: Job.t(),
          sha: <<_::320>>,
          ref: String.t(),
          detector: Detector.t(),
          metadata: %{optional(String.t()) => String.t() | integer() | float() | boolean()} | nil,
          scanned: DateTime.t(),
          manifests: manifests() | nil
        }

  @derive Jason.Encoder
  @enforce_keys [:version, :job, :sha, :ref, :detector, :scanned]
  defstruct [:version, :job, :sha, :ref, :detector, :scanned, metadata: nil, manifests: nil]

  @app Mix.Project.config()[:app]
  @version Mix.Project.config()[:version]
  @url Mix.Project.config()[:source_url]

  @detector %Detector{
    name: Atom.to_string(@app),
    version: Version.parse!(@version),
    url: URI.new!(@url)
  }

  # https://github.com/elixir-lang/elixir/issues/14837
  # Issue with opaque URI.t() type
  @dialyzer {:nowarn_function, new: 1}

  @doc """
  Creates a new dependency submission struct from GitHub-related metadata and resolved manifests.

  ## Examples

      iex> MixDependencySubmission.Submission.new(%{
      ...>   github_job_id: "job123",
      ...>   github_workflow: "build.yml",
      ...>   ref: "refs/heads/main",
      ...>   sha: "sha",
      ...>   manifests: %{},
      ...>   scanned: ~U[2025-04-19 10:05:38.170646Z]
      ...> })
      %MixDependencySubmission.Submission{
        version: 0,
        job: %MixDependencySubmission.Submission.Job{
          id: "job123",
          correlator: "build.yml job123",
          html_url: nil
        },
        sha: "sha",
        ref: "refs/heads/main",
        detector: %MixDependencySubmission.Submission.Detector{
          name: "mix_dependency_submission",
          version: #{inspect(Version.parse!(@version))},
          url: %URI{
            scheme: "https",
            userinfo: nil,
            host: "github.com",
            port: 443,
            path: "/erlef/mix-dependency-submission",
            query: nil,
            fragment: nil
          }
        },
        scanned: ~U[2025-04-19 10:05:38.170646Z],
        metadata: %{},
        manifests: %{}
      }

  """
  @spec new(
          options :: %{
            required(:github_job_id) => String.t(),
            required(:github_workflow) => String.t(),
            required(:ref) => String.t(),
            required(:sha) => String.t(),
            required(:manifests) => manifests(),
            optional(:scanned) => DateTime.t()
          }
        ) :: t()
  def new(
        %{github_job_id: github_job_id, github_workflow: github_workflow, sha: sha, ref: ref, manifests: manifests} =
          options
      ) do
    %__MODULE__{
      version: 0,
      job: %Job{
        id: github_job_id,
        correlator: "#{github_workflow} #{github_job_id}"
      },
      sha: sha,
      ref: ref,
      detector: @detector,
      metadata: %{},
      scanned: options[:scanned] || DateTime.utc_now(),
      manifests: manifests
    }
  end
end
