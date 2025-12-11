defmodule MixDependencySubmission.Submission.Manifest.Dependency do
  @moduledoc """
  Represents a dependency entry in the submission manifest.

  Used to describe individual dependencies with metadata, scope, and
  relationship information, including any nested dependencies via `purl`s.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository
  """

  alias SBoM.CycloneDX.V17, as: CycloneDX

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

  @spec from_bom_component(
          component :: CycloneDX.Component.t(),
          bom :: CycloneDX.Bom.t()
        ) :: t()
  def from_bom_component(%CycloneDX.Component{purl: purl, scope: scope} = component, %CycloneDX.Bom{} = bom) do
    root_dependencies = find_component_dependencies(bom, bom.metadata.component)
    dependencies = find_component_dependencies(bom, component)

    scope =
      case scope do
        :SCOPE_REQUIRED -> :runtime
        :SCOPE_OPTIONAL -> :runtime
        :SCOPE_EXCLUDED -> :development
      end

    %__MODULE__{
      scope: scope,
      metadata: %{
        "license" => license_from_component(component)
      },
      dependencies: Enum.map(dependencies, &purl(&1.purl)),
      relationship: if(component in root_dependencies, do: :direct, else: :indirect),
      package_url: purl(purl)
    }
  end

  @spec find_component_dependencies(
          bom :: CycloneDX.Bom.t(),
          component :: CycloneDX.Component.t()
        ) ::
          [CycloneDX.Component.t()]
  defp find_component_dependencies(%CycloneDX.Bom{} = bom, %CycloneDX.Component{bom_ref: bom_ref}) do
    %CycloneDX.Dependency{dependencies: dependencies} =
      Enum.find(
        bom.dependencies,
        %CycloneDX.Dependency{},
        &match?(%CycloneDX.Dependency{ref: ^bom_ref}, &1)
      )

    for %CycloneDX.Dependency{ref: ref} <- dependencies do
      if bom.metadata.component.bom_ref == ref do
        bom.metadata.component
      else
        Enum.find(bom.components, &match?(%CycloneDX.Component{bom_ref: ^ref}, &1))
      end
    end
  end

  @spec license_from_component(component :: CycloneDX.Component.t()) :: String.t() | nil
  defp license_from_component(%CycloneDX.Component{licenses: []}), do: nil

  defp license_from_component(%CycloneDX.Component{licenses: licenses}) do
    licenses
    |> Enum.map(fn %CycloneDX.LicenseChoice{choice: {:license, license}} -> license end)
    |> Enum.map_join(" AND ", fn %CycloneDX.License{license: {:id, id}} -> id end)
  end

  @spec purl(purl :: String.t()) :: Purl.t()
  defp purl(purl) do
    case Purl.new!(purl) do
      # GitHub does not yet support the "otp" type in purls
      # TODO: Remove this when GitHub adds support
      %Purl{type: "otp"} = purl -> Purl.new!(%{purl | type: "generic"})
      purl -> purl
    end
  end

  defimpl Jason.Encoder do
    @impl Jason.Encoder
    def encode(value, opts) do
      value
      |> Map.from_struct()
      |> update_in([:package_url], &purl_to_string/1)
      |> update_in([:dependencies], &List.wrap/1)
      |> update_in([:dependencies, Access.all()], &purl_to_string/1)
      |> Enum.reject(fn {_key, value} -> value in [nil, []] end)
      |> Map.new()
      |> Jason.Encode.map(opts)
    end

    @spec purl_to_string(purl :: Purl.t()) :: String.t()
    @spec purl_to_string(purl :: nil) :: nil
    defp purl_to_string(purl)
    defp purl_to_string(nil), do: nil
    defp purl_to_string(%Purl{} = purl), do: Purl.to_string(purl)
  end
end
