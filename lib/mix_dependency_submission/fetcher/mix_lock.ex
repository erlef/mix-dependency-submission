defmodule MixDependencySubmission.Fetcher.MixLock do
  @moduledoc """
  Fetches dependencies from the `mix.lock` file.

  This module implements the `MixDependencySubmission.Fetcher` behaviour to extract
  locked dependencies and convert them into the expected internal format.
  """

  @behaviour MixDependencySubmission.Fetcher

  alias MixDependencySubmission.Fetcher

  require Logger

  @doc """
  Reads and normalizes locked dependencies from the `mix.lock` file.

  Returns `nil` if the lockfile doesn't exist.

  ## Examples

      iex> %{burrito: %{scm: Hex.SCM, mix_lock: [:hex, :burrito | _]}} =
      ...>   MixDependencySubmission.Fetcher.MixLock.fetch()

  Note: This test assumes an Elixir project that is currently loaded with a
  `mix.lock` file in place.
  """
  @impl Fetcher
  def fetch do
    lockfile_name = Mix.Project.config()[:lockfile]
    lockfile_path = Path.expand(lockfile_name, Path.dirname(Mix.Project.project_file()))

    if Elixir.File.exists?(lockfile_path) do
      lock = read(lockfile_path)

      Map.new(lock, &normalize_dep/1)
    end
  end

  @spec read(lockfile :: Path.t()) :: %{String.t() => tuple()}
  defp read(lockfile) do
    opts = [file: lockfile, emit_warnings: false]

    with {:ok, contents} <- Elixir.File.read(lockfile),
         {:ok, quoted} <- Code.string_to_quoted(contents, opts),
         {%{} = lock, _binding} <- Code.eval_quoted(quoted, [], opts) do
      lock
    else
      {:error, reason} ->
        Logger.warning("Failed to read lockfile #{lockfile}, reason: #{inspect(reason, pretty: true)}")

        %{}
    end
  end

  @spec normalize_dep(dep :: {Fetcher.app_name(), tuple()}) ::
          {Fetcher.app_name(), Fetcher.dependency()}
  defp normalize_dep({app, lock} = _dep) do
    scm = Enum.find(Mix.SCM.available(), & &1.format_lock(lock: lock))

    {app,
     %{
       scm: scm,
       mix_lock: Tuple.to_list(lock)
     }}
  end
end
