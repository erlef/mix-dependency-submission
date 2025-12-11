defmodule MixDependencySubmission do
  @moduledoc """
  Builds the dependency submission payload from one or more Mix projects.

  Responsible for collecting dependency data, resolving manifests, and
  assembling the top-level submission struct to be sent to GitHub.

  See https://docs.github.com/en/rest/dependency-graph/dependency-submission?apiVersion=2022-11-28#create-a-snapshot-of-dependencies-for-a-repository

  > #### API Interface {: .warning}
  > This project is **not a library** and is intended **only** for use as a
  > GitHub Action. All modules, functions, and types are considered internal and
  > may change at any time without notice.
  >
  > If you're looking to integrate this functionality into your own tooling, open
  > an issue to discuss the use case, but do not rely on this as a stable library
  > interface.

  """

  alias MixDependencySubmission.Submission
  alias MixDependencySubmission.Submission.Manifest
  alias MixDependencySubmission.Submission.Manifest.Dependency
  alias MixDependencySubmission.Util

  @doc """
  Builds a new `MixDependencySubmission.Submission` from a set of project
  options.

  Finds nested Mix projects (unless ignored), resolves dependencies,
  and prepares the manifest payload.

  ## Examples

      iex> MixDependencySubmission.submission(
      ...>   github_job_id: "job123",
      ...>   github_workflow: "ci.yml",
      ...>   sha: "sha",
      ...>   ref: "refs/heads/main",
      ...>   project_path: ".",
      ...>   install_deps?: false,
      ...>   ignore: []
      ...> )
      %MixDependencySubmission.Submission{
        version: 0,
        job: %MixDependencySubmission.Submission.Job{
          id: "job123",
          correlator: "ci.yml job123",
          html_url: nil
        },
        sha: "sha",
        ref: "refs/heads/main",
        detector: %MixDependencySubmission.Submission.Detector{
          name: "mix_dependency_submission",
          version: %Version{major: 1, minor: 0, patch: 0, pre: ["beta", 8]},
          url: %URI{
            scheme: "https",
            userinfo: nil,
            host: "github.com",
            port: 443,
            path: "/erlef/mix-dependency-submission",
            query: nil,
            fragment: nil
          }
        },
        scanned: ~U[2025-04-19 10:15:11.656801Z],
        metadata: %{},
        manifests: %{
          "mix.exs" => %MixDependencySubmission.Submission.Manifest{
            name: "mix.exs",
            file: %MixDependencySubmission.Submission.Manifest.File{
              source_location: "mix.exs"
            },
            metadata: %{},
            resolved: %{
              "expo" => %MixDependencySubmission.Submission.Manifest.Dependency{
                package_url:
                  Purl.parse!(
                    "pkg:github/elixir-gettext/expo@2ae85019d62288001bdc4a949d65bf650beee315"
                  ),
                metadata: %{},
                relationship: :direct,
                scope: :runtime,
                dependencies: []
              }
            }
          }
        }
      }

  """
  @spec submission(
          options :: [
            {:github_job_id, String.t()}
            | {:github_workflow, String.t()}
            | {:ref, String.t()}
            | {:sha, String.t()}
            | {:project_path, Path.t()}
            | {:paths_relative_to, Path.t()}
            | {:install_deps?, boolean()}
            | {:ignore, [Path.t()]}
          ]
        ) :: Submission.t()
  def submission(options) do
    options =
      options
      |> Keyword.put_new(:project_path, &File.cwd!/0)
      |> Keyword.update!(:project_path, &Path.expand/1)

    options =
      options
      |> Keyword.put_new(:paths_relative_to, options[:project_path])
      |> Keyword.update!(:paths_relative_to, &Path.expand/1)

    manifests =
      options[:project_path]
      |> find_mix_projects(options[:ignore] || [], options[:paths_relative_to])
      |> Map.new(fn project_path ->
        manifest =
          manifest(project_path, Keyword.take(options, [:paths_relative_to, :install_deps?]))

        {manifest.file.source_location, manifest}
      end)

    Submission.new(%{
      github_job_id: Keyword.fetch!(options, :github_job_id),
      github_workflow: Keyword.fetch!(options, :github_workflow),
      sha: Keyword.fetch!(options, :sha),
      ref: Keyword.fetch!(options, :ref),
      manifests: manifests
    })
  end

  @doc """
  Resolves the dependency manifest for a single Mix project.

  Optionally installs dependencies beforehand if `install_deps?` is true.
  """
  @spec manifest(
          project_path :: Path.t(),
          options :: [{:paths_relative_to, Path.t()} | {:install_deps?, boolean()}]
        ) ::
          Manifest.t()
  def manifest(project_path, options) do
    Util.in_project(project_path, fn _mix_module ->
      if options[:install_deps?] do
        Mix.Task.run("deps.get")
      end

      make_manifest(SBoM.CycloneDX.bom(), project_path, options[:paths_relative_to])
    end)
  end

  @spec find_mix_projects(
          project_path :: Path.t(),
          ignore :: [Path.t()],
          paths_relative_to :: Path.t()
        ) :: [Path.t()]
  defp find_mix_projects(project_path, ignore, paths_relative_to) do
    ignore = Enum.map(ignore, &Path.expand(&1, paths_relative_to))

    project_path
    |> Path.join("**/mix.exs")
    |> Path.wildcard()
    |> Enum.map(&Path.dirname/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.reject(fn path ->
      Enum.any?(ignore, &String.starts_with?(path, &1)) or
        path |> Path.split() |> Enum.member?("deps")
    end)
    # No more than 1000, otherwise something went wrong like scanning deps...
    |> Enum.take(1000)
  end

  @spec make_manifest(
          bom :: SBoM.CycloneDX.V17.Bom.t(),
          project_path :: Path.t(),
          paths_relative_to :: Path.t()
        ) :: Manifest.t()
  defp make_manifest(bom, project_path, paths_relative_to) do
    metadata =
      %{"license" => Enum.join(Mix.Project.config()[:package][:licenses] || [], " AND ")}

    %Manifest{
      name: "mix.exs",
      file: %Manifest.File{
        source_location: project_path |> Path.join("mix.exs") |> Path.relative_to(paths_relative_to)
      },
      resolved:
        for component <- bom.components, into: %{} do
          {component.name, Dependency.from_bom_component(component, bom)}
        end,
      metadata: drop_empty(metadata)
    }
  end

  @spec drop_empty(map :: %{key => value | nil}) :: %{key => value}
        when key: term(), value: term()
  defp drop_empty(map), do: map |> Enum.reject(fn {_key, value} -> value in [nil, ""] end) |> Map.new()
end
