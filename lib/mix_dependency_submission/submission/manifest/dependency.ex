defmodule MixDependencySubmission.Submission.Manifest.Dependency do
  @moduledoc """
  Represents a dependency entry in the submission manifest.

  Used to describe individual dependencies with metadata, scope, and
  relationship information, including any nested dependencies via `purl`s.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  @type relationship() :: :direct | :indirect
  @type scope() :: :runtime | :development

  @type t :: %__MODULE__{
          package_url: Purl.t() | nil,
          metadata: %{optional(String.t()) => String.t() | integer() | float() | boolean()} | nil,
          relationship: relationship() | nil,
          scope: scope() | nil,
          dependencies: [Purl.t()] | nil
        }

  @enforce_keys []
  defstruct package_url: nil, metadata: nil, relationship: nil, scope: nil, dependencies: nil

  defimpl JSON.Encoder do
    @impl JSON.Encoder
    def encode(value, encoder) do
      value
      |> Map.from_struct()
      |> update_in([:package_url], &purl_to_string/1)
      |> update_in([:dependencies], &List.wrap/1)
      |> update_in([:dependencies, Access.all()], &purl_to_string/1)
      |> Enum.reject(fn {_key, value} -> value in [nil, []] end)
      |> Map.new()
      |> encoder.(encoder)
    end

    @spec purl_to_string(purl :: Purl.t()) :: String.t()
    @spec purl_to_string(purl :: nil) :: nil
    defp purl_to_string(purl)
    defp purl_to_string(nil), do: nil
    defp purl_to_string(%Purl{} = purl), do: Purl.to_string(purl)
  end
end
