defmodule MixDependencySubmission.Fetcher.MixRuntime do
  @moduledoc """
  Fetches dependencies from the compiled Mix project at runtime.

  This fetcher uses `Mix.Project.deps_tree/1` and related project metadata to
  collect runtime dependency information including versions, SCMs, and
  relationships.
  """

  @behaviour MixDependencySubmission.Fetcher

  alias MixDependencySubmission.Fetcher

  @doc """
  Fetches all runtime dependencies from the current Mix project.

  Includes both direct and indirect dependencies as resolved from the dependency
  tree at runtime.

  ## Examples

      iex> %{
      ...>   burrito: %{
      ...>     scm: Hex.SCM,
      ...>     dependencies: [:jason, :req, :typed_struct, :kernel, :stdlib, :elixir, :logger, :eex],
      ...>     mix_config: _config,
      ...>     relationship: :direct,
      ...>     scope: :runtime,
      ...>     version: _version
      ...>   }
      ...> } =
      ...>   MixDependencySubmission.Fetcher.MixRuntime.fetch()

  Note: This test assumes an Elixir project that is currently loaded.
  """
  @impl Fetcher
  def fetch do
    app = Mix.Project.config()[:app]

    root_deps =
      [depth: 1]
      |> Mix.Project.deps_tree()
      |> Map.keys()
      |> Enum.concat(get_app_dependencies(app, true))
      |> Enum.uniq()

    deps_tree = full_runtime_tree(app)

    deps_paths =
      deps_tree
      |> Map.keys()
      |> Enum.reduce(Mix.Project.deps_paths(), fn dep, deps_paths ->
        try do
          app_dir = Application.app_dir(dep)
          Map.put_new(deps_paths, dep, app_dir)
        rescue
          ArgumentError ->
            deps_paths
        end
      end)

    deps_scms =
      deps_tree
      |> Map.keys()
      |> Enum.reduce(Mix.Project.deps_scms(), fn dep, deps_scms ->
        Map.put_new(deps_scms, dep, MixDependencySubmission.SCM.System)
      end)

    Map.new(deps_tree, &resolve_dep(&1, root_deps, deps_paths, deps_scms))
  end

  @spec full_runtime_tree(app :: Fetcher.app_name()) :: %{
          Fetcher.app_name() => [Fetcher.app_name()]
        }
  defp full_runtime_tree(app) do
    app_dependencies = app |> get_app_dependencies(true) |> Enum.map(&{&1, []})

    Mix.Project.deps_tree()
    |> Enum.concat(app_dependencies)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {app, dependencies} ->
      dependencies =
        [dependencies | get_app_dependencies(app, false)] |> List.flatten() |> Enum.uniq()

      [{app, dependencies} | Enum.map(dependencies, &{&1, []})]
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {app, dependencies} ->
      {app, dependencies |> List.flatten() |> Enum.uniq()}
    end)
  end

  @spec get_app_dependencies(app :: Fetcher.app_name(), root? :: boolean()) :: [
          Fetcher.app_name()
        ]
  defp get_app_dependencies(app, root?)
  defp get_app_dependencies(nil, _root?), do: []

  defp get_app_dependencies(app, root?) do
    case Application.spec(app) do
      nil ->
        []

      spec ->
        included = spec[:included_applications] || []
        applications = spec[:applications] || []
        optional = spec[:optional_applications] || []

        if root? do
          Enum.uniq(included ++ applications ++ optional)
        else
          Enum.uniq(included ++ (applications -- optional))
        end
    end
  end

  @spec resolve_dep(
          dep :: {Fetcher.app_name(), [Fetcher.app_name()]},
          root_deps :: [Fetcher.app_name()],
          deps_paths :: %{Fetcher.app_name() => Path.t()},
          deps_scms :: %{Fetcher.app_name() => module()}
        ) :: {Fetcher.app_name(), Fetcher.dependency()}
  defp resolve_dep({app, dependencies}, root_deps, deps_paths, deps_scms) do
    dep_path = Map.fetch!(deps_paths, app)
    dep_scm = Map.fetch!(deps_scms, app)

    config =
      if Elixir.File.exists?(dep_path) do
        Mix.Project.in_project(app, Map.fetch!(deps_paths, app), fn _module ->
          Mix.Project.config()
        end)
      else
        []
      end

    relationship = if(app in root_deps, do: :direct, else: :indirect)

    {app,
     %{
       scm: dep_scm,
       version: config[:version],
       scope: :runtime,
       relationship: relationship,
       dependencies: dependencies,
       mix_config: config
     }}
  end
end
