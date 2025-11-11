defmodule MixDependencySubmission.Submission.Job do
  @moduledoc """
  Represents the job entry in the submission manifest.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  @type t :: %__MODULE__{
          id: String.t(),
          correlator: String.t(),
          html_url: URI.t() | nil
        }

  @enforce_keys [:id, :correlator]
  defstruct [:id, :correlator, html_url: nil]

  defimpl JSON.Encoder do
    @impl JSON.Encoder
    def encode(value, encoder) do
      value
      |> Map.from_struct()
      |> Map.update!(:html_url, &uri_to_string/1)
      |> Enum.reject(&match?({_key, nil}, &1))
      |> Map.new()
      |> encoder.(encoder)
    end

    @spec uri_to_string(uri :: URI.t()) :: String.t()
    @spec uri_to_string(uri :: nil) :: nil
    defp uri_to_string(uri)
    defp uri_to_string(nil), do: nil
    defp uri_to_string(%URI{} = uri), do: URI.to_string(uri)
  end
end
