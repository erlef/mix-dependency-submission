defmodule MixDependencySubmission.Application do
  @moduledoc false

  use Application

  alias Burrito.Util.Args
  alias MixDependencySubmission.CLI.Submit

  require Logger

  @impl Application
  def start(_start_type, _start_args) do
    if Burrito.Util.running_standalone?() do
      exit_code = Submit.run(Args.argv())

      System.stop(exit_code)
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
