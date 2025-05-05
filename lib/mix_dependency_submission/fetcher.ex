defmodule MixDependencySubmission.Fetcher do
  @moduledoc """
  Defines the behaviour for manifest fetchers and provides an entry point to collect
  dependency data from multiple sources.

  The built-in fetchers include:

    * `MixDependencySubmission.Fetcher.MixFile` — parses `mix.exs`
    * `MixDependencySubmission.Fetcher.MixLock` — parses `mix.lock`
    * `MixDependencySubmission.Fetcher.MixRuntime` — inspects runtime dependency
      graph
  """

  alias MixDependencySubmission.SCM
  alias MixDependencySubmission.Submission.Manifest.Dependency

  @type app_name() :: atom()
  @type mix_dep() :: {app_name(), requirement :: String.t(), opts :: Keyword.t()}

  @type dependency() :: %{
          optional(:scm) => module(),
          optional(:version) => String.t(),
          optional(:mix_dep) => mix_dep(),
          optional(:mix_lock) => MixDependencySubmission.SCM.lock(),
          optional(:scope) => Dependency.scope(),
          optional(:relationship) => Dependency.relationship(),
          optional(:dependencies) => [app_name()],
          optional(:mix_config) => Keyword.t()
        }

  @doc """
  Fetches dependencies from a specific source.

  Implementers must return a map of app names to raw dependency data, or `nil`
  if no data is available.

  This callback is used by the main `MixDependencySubmission.Fetcher.fetch/0`
  function to gather and merge data from multiple sources like `mix.exs`,
  `mix.lock`, or the compiled dependency graph.

  ## Example return value

      %{
        my_dep: %{
          scm: Mix.SCM.Hex,
          version: "0.1.0",
          scope: :runtime,
          relationship: :direct
        }
      }

  Returning `nil` signals that no data could be fetched by the implementation.
  """
  @callback fetch() :: %{optional(app_name()) => dependency()} | nil

  @manifest_fetchers [__MODULE__.MixFile, __MODULE__.MixLock, __MODULE__.MixRuntime]

  @doc """
  Fetches and merges dependencies from all registered fetchers.

  Returns a map of stringified app names to structured `Dependency` records,
  ready to be submitted as a manifest.

  ## Examples

      iex> %{
      ...>   "burrito" => %MixDependencySubmission.Submission.Manifest.Dependency{
      ...>     package_url: %Purl{type: "hex", name: "burrito"},
      ...>     metadata: %{},
      ...>     relationship: :direct,
      ...>     scope: :runtime,
      ...>     dependencies: _dependencies
      ...>   }
      ...> } = MixDependencySubmission.Fetcher.fetch()

  Note: This test assumes an Elixir project that is currently loaded.
  """
  @spec fetch() :: %{String.t() => Dependency.t()} | nil
  def fetch do
    @manifest_fetchers
    |> Enum.map(& &1.fetch())
    |> Enum.reduce(nil, fn
      nil, acc ->
        acc

      dependencies, acc ->
        Map.merge(acc || %{}, dependencies, &merge/3)
    end)
    |> case do
      nil -> nil
      %{} = deps -> transform_all(deps)
    end
  end

  @spec merge(app_name(), left :: dependency(), right :: dependency()) :: dependency()
  defp merge(_app, left, right), do: Map.merge(left, right)

  @spec transform_all(dependencies :: %{app_name() => dependency()}) :: %{
          String.t() => Dependency.t()
        }
  defp transform_all(dependencies) do
    dependencies =
      Map.new(dependencies, fn {app, dependency} ->
        {app, transform(app, drop_empty(dependency))}
      end)

    Map.new(dependencies, fn {app, dependency} ->
      dependency =
        dependency
        |> update_in(
          [Access.key!(:dependencies), Access.all()],
          &get_in(dependencies, [Access.key(&1), Access.key!(:package_url)])
        )
        |> update_in([Access.key!(:dependencies)], fn list -> Enum.reject(list, &is_nil/1) end)

      {Atom.to_string(app), dependency}
    end)
  end

  @spec transform(app_name(), dependency()) :: Dependency.t()
  defp transform(app, dependency) do
    sub_dependencies =
      Enum.uniq((dependency[:dependencies] || []) ++ lock_dependencies(dependency))

    purl = package_url(dependency, app)

    purl =
      case mix_config_source_url(dependency[:mix_config]) do
        nil -> purl
        url -> %{purl | qualifiers: Map.put_new(purl.qualifiers, "vcs_url", url)}
      end

    metadata =
      %{"license" => Enum.join(dependency[:mix_config][:package][:licenses] || [], " AND ")}

    %Dependency{
      package_url: purl,
      metadata: drop_empty(metadata),
      relationship: dependency[:relationship],
      scope: dependency[:scope],
      dependencies: sub_dependencies
    }
  end

  @spec mix_config_source_url(mix_config :: Keyword.t()) :: String.t() | nil
  defp mix_config_source_url(mix_config) do
    links =
      Map.new(mix_config[:package][:links] || %{}, fn {key, value} ->
        {String.downcase(to_string(key)), value}
      end)

    mix_config[:source_url] ||
      links["github"] ||
      links["gitlab"] ||
      links["git"] ||
      links["source"] ||
      links["repository"] ||
      links["bitbucket"]
  end

  @spec package_url(dependency(), app_name()) :: Purl.t()
  defp package_url(dependency, app)

  defp package_url(%{scm: scm, mix_lock: mix_lock} = dependency, app) do
    case SCM.implementation(scm) do
      nil ->
        dependency |> Map.drop(~w[mix_lock]a) |> package_url(app)

      impl ->
        if function_exported?(impl, :mix_lock_to_purl, 2) do
          impl.mix_lock_to_purl(app, mix_lock)
        else
          dependency |> Map.drop(~w[mix_lock]a) |> package_url(app)
        end
    end
  end

  defp package_url(%{scm: scm, mix_dep: mix_dep} = dependency, app) do
    case SCM.implementation(scm) do
      nil -> dependency |> Map.drop(~w[mix_dep]a) |> package_url(app)
      impl -> impl.mix_dep_to_purl(mix_dep, dependency[:version])
    end
  end

  defp package_url(dependency, app) do
    Purl.new!(%Purl{
      type: "generic",
      name: Atom.to_string(app),
      version: dependency[:version]
    })
  end

  @spec lock_dependencies(dependency()) :: [app_name()]
  defp lock_dependencies(dependency)

  defp lock_dependencies(%{scm: scm, mix_lock: mix_lock} = dependency) do
    case SCM.implementation(scm) do
      nil ->
        dependency |> Map.drop(~w[scm]a) |> lock_dependencies()

      impl ->
        if function_exported?(impl, :mix_lock_deps, 1) do
          impl.mix_lock_deps(mix_lock)
        else
          dependency |> Map.drop(~w[scm]a) |> lock_dependencies()
        end
    end
  end

  defp lock_dependencies(_dependency), do: []

  @spec drop_empty(map :: %{key => value | nil}) :: %{key => value}
        when key: term(), value: term()
  defp drop_empty(map), do: map |> Enum.reject(fn {_key, value} -> value in [nil, ""] end) |> Map.new()
end
