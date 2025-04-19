defmodule MixDependencySubmission.Submission.Detector do
  @moduledoc """
  Represents the detector entry in the submission manifest.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  @type t :: %__MODULE__{
          name: String.t(),
          version: Version.t(),
          url: URI.t()
        }

  @enforce_keys [:name, :version, :url]
  defstruct [:name, :version, :url]

  defimpl Jason.Encoder do
    @impl Jason.Encoder
    def encode(value, opts) do
      value
      |> Map.from_struct()
      |> Map.update!(:version, &Version.to_string/1)
      |> Map.update!(:url, &URI.to_string/1)
      |> Jason.Encode.map(opts)
    end
  end
end
