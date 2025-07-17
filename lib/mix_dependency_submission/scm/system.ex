defmodule MixDependencySubmission.SCM.System do
  @moduledoc """
  A `Mix.SCM` implementation that looks up the system dependencies.
  (Erlang, Elixir, Hex, etc.)
  """

  @behaviour Mix.SCM

  @elixir_applications ~w[eex elixir ex_unit iex logger mix]a
  defguard is_elixir_app(app) when app in @elixir_applications

  {:ok, dirs} = :file.list_dir_all(:code.lib_dir())

  @erlang_applications Enum.map(dirs, fn dir ->
                         [name, _version] = dir |> List.to_string() |> String.split("-", parts: 2)
                         String.to_atom(name)
                       end)

  defguard is_erlang_app(app) when app in @erlang_applications

  defguard is_hex_app(app) when app == :hex
  defguard is_system_app(app) when is_elixir_app(app) or is_erlang_app(app) or is_hex_app(app)

  @impl Mix.SCM
  def accepts_options(app, opts)

  def accepts_options(app, opts) when is_system_app(app),
    do: Keyword.merge(opts, app: app, build: Application.app_dir(app), dest: Application.app_dir(app))

  def accepts_options(_app, _opts), do: nil

  @impl Mix.SCM
  def fetchable?, do: false

  @impl Mix.SCM
  def format(opts), do: opts[:app]

  @impl Mix.SCM
  def format_lock(_opts), do: nil

  @impl Mix.SCM
  def checked_out?(_opts), do: true

  @impl Mix.SCM
  def lock_status(_opts), do: :ok

  @impl Mix.SCM
  def equal?(opts1, opts2), do: opts1[:app] == opts2[:app]

  @impl Mix.SCM
  def managers(_opts), do: []

  @impl Mix.SCM
  @dialyzer {:no_return, checkout: 1}
  def checkout(_opts), do: Mix.raise("System SCM does not support checkout.")

  @impl Mix.SCM
  @dialyzer {:no_return, update: 1}
  def update(_opts), do: Mix.raise("System SCM does not support update.")
end

defmodule MixDependencySubmission.SCM.MixDependencySubmission.SCM.System do
  @moduledoc """
  `MixDependencySubmission.SCM` implementation for system dependencies.
  """

  @behaviour MixDependencySubmission.SCM

  import MixDependencySubmission.SCM.System,
    only: [is_elixir_app: 1, is_erlang_app: 1, is_hex_app: 1]

  @impl MixDependencySubmission.SCM
  def mix_dep_to_purl(app, version)

  def mix_dep_to_purl({app, _version_requirement, _opts}, _version) when is_elixir_app(app) do
    Purl.new!(%Purl{
      type: "generic",
      # TODO: Use once the spec is merged
      # type: "otp",
      name: to_string(app),
      subpath: ["lib", to_string(app)],
      qualifiers: %{"vcs_url" => "git+https://github.com/elixir-lang/elixir.git"}
    })
  end

  def mix_dep_to_purl({app, _version_requirement, _opts}, _version) when is_erlang_app(app) do
    Purl.new!(%Purl{
      type: "generic",
      # TODO: Use once the spec is merged
      # type: "otp",
      name: to_string(app),
      subpath: ["lib", to_string(app)],
      qualifiers: %{"vcs_url" => "git+https://github.com/erlang/otp.git"}
    })
  end

  def mix_dep_to_purl({app, _version_requirement, _opts}, _version) when is_hex_app(app) do
    Purl.new!(%Purl{
      type: "generic",
      # TODO: Use once the spec is merged
      # type: "otp",
      name: to_string(app),
      qualifiers: %{"vcs_url" => "git+https://github.com/hexpm/hex.git"}
    })
  end
end
