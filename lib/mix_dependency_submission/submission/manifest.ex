defmodule MixDependencySubmission.Submission.Manifest do
  @moduledoc """
  Represents a manifest entry in the submission payload.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  alias MixDependencySubmission.Submission.Manifest.Dependency
  alias MixDependencySubmission.Submission.Manifest.File

  @type t :: %__MODULE__{
          name: String.t(),
          file: File.t() | nil,
          metadata: %{optional(String.t()) => String.t() | integer() | float() | boolean()} | nil,
          resolved: %{optional(String.t()) => Dependency.t()} | nil
        }

  @enforce_keys [:name]
  defstruct [:name, file: nil, metadata: nil, resolved: nil]

  defimpl JSON.Encoder do
    @impl JSON.Encoder
    def encode(value, encoder) do
      value
      |> Map.from_struct()
      |> Enum.reject(&match?({_key, nil}, &1))
      |> Map.new()
      |> encoder.(encoder)
    end
  end
end
