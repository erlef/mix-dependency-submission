defmodule MixDependencySubmission.Fetcher.MixFile do
  @moduledoc """
  A `MixDependencySubmission.Fetcher` implementation that extracts dependencies
  from the current project's `mix.exs` file.

  This module is responsible for reading and normalizing direct dependencies
  defined in the project configuration, returning them in a standard format
  expected by the submission tool.
  """

  @behaviour MixDependencySubmission.Fetcher

  alias MixDependencySubmission.Fetcher

  @doc """
  Fetches and normalizes the direct dependencies defined in the `mix.exs` file.

  This implementation reads the project configuration via
  `Mix.Project.config()[:deps]` and normalizes each dependency entry.

  ## Examples

      iex> %{
      ...>   burrito: %{
      ...>     scm: Hex.SCM,
      ...>     mix_dep: _dep,
      ...>     relationship: :direct,
      ...>     scope: :runtime
      ...>   }
      ...> } =
      ...>   MixDependencySubmission.Fetcher.MixFile.fetch()

  Note: This test assumes an Elixir project that is currently loaded with a
  `mix.exs` file in place.
  """
  @impl Fetcher
  def fetch do
    Mix.Project.config()[:deps] |> List.wrap() |> Map.new(&normalize_dep/1)
  end

  @spec normalize_dep(
          dep ::
            {Fetcher.app_name(), String.t()}
            | {Fetcher.app_name(), Keyword.t()}
            | {Fetcher.app_name(), String.t() | nil, Keyword.t()}
        ) :: {Fetcher.app_name(), Fetcher.dependency()}
  defp normalize_dep(dep)

  defp normalize_dep({app, requirement}) when is_atom(app) and is_binary(requirement),
    do: normalize_dep({app, requirement, []})

  defp normalize_dep({app, opts}) when is_atom(app) and is_list(opts), do: normalize_dep({app, nil, opts})

  defp normalize_dep({app, requirement, opts})
       when is_atom(app) and (is_binary(requirement) or is_nil(requirement)) and is_list(opts) do
    {scm, opts} =
      Enum.find_value(Mix.SCM.available(), {nil, opts}, fn scm ->
        case scm.accepts_options(app, opts) do
          nil -> false
          opts -> {scm, opts}
        end
      end)

    {app,
     %{
       scm: scm,
       mix_dep: {app, requirement, opts},
       relationship: :direct,
       scope: dependency_scope(opts)
     }}
  end

  @spec dependency_scope(opts :: Keyword.t()) :: :runtime | :development
  defp dependency_scope(opts) do
    runtime = Keyword.get(opts, :runtime, true)

    only =
      case Keyword.get(opts, :only, [:prod]) do
        list when is_list(list) -> list
        entry -> [entry]
      end

    cond do
      !runtime -> :development
      :prod not in only -> :development
      true -> :runtime
    end
  end
end
