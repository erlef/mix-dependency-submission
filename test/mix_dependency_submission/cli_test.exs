defmodule MixDependencySubmission.CLITest do
  use MixDependencySubmission.EnvCase, async: false

  import ExUnit.CaptureIO

  alias MixDependencySubmission.CLI

  doctest CLI

  describe inspect(&CLI.parse!/1) do
    test "parses valid arguments" do
      argv =
        ~w[--github-repository org/repo --github-job-id 123 --github-workflow build --sha sha --ref refs/heads/main --github-token ghp_xxx --github-api-url https://github.corp.com]

      result = CLI.parse!(argv)

      assert result.options.github_repository == "org/repo"
      assert result.options.github_job_id == "123"
      assert result.options.github_workflow == "build"
      assert result.options.sha == "sha"
      assert result.options.ref == "refs/heads/main"
      assert result.options.github_token == "ghp_xxx"
      assert result.options.github_api_url == "https://github.corp.com"
    end

    test "uses default values from env variables" do
      System.put_env("GITHUB_REPOSITORY", "org/repo")
      System.put_env("GITHUB_JOB", "123")
      System.put_env("GITHUB_WORKFLOW", "default_workflow")
      System.put_env("GITHUB_SHA", "default_sha")
      System.put_env("GITHUB_REF", "refs/heads/main")
      System.put_env("GITHUB_TOKEN", "ghp_xxx")

      result = CLI.parse!([])

      assert result.options.github_repository == "org/repo"
      assert result.options.github_job_id == "123"
      assert result.options.github_workflow == "default_workflow"
      assert result.options.sha == "default_sha"
      assert result.options.ref == "refs/heads/main"
      assert result.options.github_token == "ghp_xxx"
    end

    test "halts on invalid url" do
      argv =
        ~w[--github-repository org/repo --github-job-id 123 --github-workflow build --sha sha --ref refs/heads/main --github-token ghp_xxx --github-api-url ::]

      msg =
        capture_io(fn ->
          assert_raise RuntimeError, "Exit: 1", fn ->
            CLI.parse!(argv)
          end
        end)

      assert msg =~ "invalid value"
    end

    test "halts on invalid path" do
      argv =
        ~w[--project-path invalid-path --github-repository org/repo --github-job-id 123 --github-workflow build --sha sha --ref refs/heads/main --github-token ghp_xxx]

      msg =
        capture_io(fn ->
          assert_raise RuntimeError, "Exit: 1", fn ->
            CLI.parse!(argv)
          end
        end)

      assert msg =~ "invalid path"
    end

    test "halts on invalid arguments" do
      argv = ~w[--invalid-option]

      msg =
        capture_io(fn ->
          assert_raise RuntimeError, "Exit: 1", fn ->
            CLI.parse!(argv)
          end
        end)

      assert msg =~ "unrecognized arguments"
    end

    test "halts on missing arguments" do
      msg =
        capture_io(fn ->
          assert_raise RuntimeError, "Exit: 1", fn ->
            CLI.parse!([])
          end
        end)

      assert msg =~ "missing required options"
    end
  end
end
