defmodule MixDependencySubmission.GithubTest do
  use MixDependencySubmission.EnvCase, async: false
  use MixDependencySubmission.FixtureCase, async: false

  alias MixDependencySubmission.GitHub

  doctest GitHub

  describe inspect(&GitHub.fetch_workspace/0) do
    test "returns the GITHUB_WORKSPACE environment variable" do
      System.put_env("GITHUB_WORKSPACE", "/path/to/workspace")
      assert {:ok, "/path/to/workspace"} = GitHub.fetch_workspace()
    end

    test "returns :error if GITHUB_WORKSPACE is not set" do
      assert :error = GitHub.fetch_workspace()
    end
  end

  describe inspect(&GitHub.get_api_url/0) do
    test "returns the GITHUB_API_URL environment variable" do
      System.put_env("GITHUB_API_URL", "https://github.corp.com")
      assert "https://github.corp.com" = GitHub.get_api_url()
    end

    test "returns default URL if GITHUB_API_URL is not set" do
      assert "https://api.github.com" = GitHub.get_api_url()
    end
  end

  describe inspect(&GitHub.fetch_repository/0) do
    test "returns the GITHUB_REPOSITORY environment variable" do
      System.put_env("GITHUB_REPOSITORY", "owner/repo")
      assert {:ok, "owner/repo"} = GitHub.fetch_repository()
    end

    test "returns :error if GITHUB_REPOSITORY is not set" do
      assert :error = GitHub.fetch_repository()
    end
  end

  describe inspect(&GitHub.fetch_job_id/0) do
    test "returns the GITHUB_JOB environment variable" do
      System.put_env("GITHUB_JOB", "job_id")
      assert {:ok, "job_id"} = GitHub.fetch_job_id()
    end

    test "returns :error if GITHUB_JOB is not set" do
      assert :error = GitHub.fetch_job_id()
    end
  end

  describe inspect(&GitHub.fetch_workflow/0) do
    test "returns the GITHUB_WORKFLOW environment variable" do
      System.put_env("GITHUB_WORKFLOW", "workflow_name")
      assert {:ok, "workflow_name"} = GitHub.fetch_workflow()
    end

    test "returns :error if GITHUB_WORKFLOW is not set" do
      assert :error = GitHub.fetch_workflow()
    end
  end

  describe inspect(&GitHub.fetch_sha/0) do
    test "returns the GITHUB_SHA environment variable" do
      System.put_env("GITHUB_SHA", "abc123")
      assert {:ok, "abc123"} = GitHub.fetch_sha()
    end

    test "returns :error if GITHUB_SHA is not set" do
      assert :error = GitHub.fetch_sha()
    end
  end

  describe inspect(&GitHub.fetch_head_sha/0) do
    test "returns the GITHUB_SHA environment variable if GITHUB_EVENT_NAME is not a PR event" do
      System.put_env("GITHUB_EVENT_NAME", "push")
      System.put_env("GITHUB_SHA", "abc123")
      assert {:ok, "abc123"} = GitHub.fetch_head_sha()
    end

    test "returns the head sha of a pull request" do
      System.put_env("GITHUB_EVENT_NAME", "pull_request")
      System.put_env("GITHUB_EVENT_PATH", app_fixture_path("github_pr_event.json"))
      System.put_env("GITHUB_SHA", "abc123")
      assert {:ok, "44b83b5998150da1cd24035e36eb93cfde07fdda"} = GitHub.fetch_head_sha()
    end

    test "returns :error if no env is set is not set" do
      assert :error = GitHub.fetch_head_sha()
    end
  end

  describe inspect(&GitHub.fetch_pr_head_sha/0) do
    test "returns the head sha of a pull request" do
      System.put_env("GITHUB_EVENT_NAME", "pull_request")
      System.put_env("GITHUB_EVENT_PATH", app_fixture_path("github_pr_event.json"))

      assert {:ok, "44b83b5998150da1cd24035e36eb93cfde07fdda"} = GitHub.fetch_pr_head_sha()
    end

    test "returns :error if GITHUB_EVENT_NAME is not a PR event" do
      System.put_env("GITHUB_EVENT_NAME", "push")
      assert :error = GitHub.fetch_pr_head_sha()
    end

    test "returns :error if GITHUB_EVENT_PATH is not set" do
      System.put_env("GITHUB_EVENT_NAME", "pull_request")
      assert :error = GitHub.fetch_pr_head_sha()
    end
  end

  describe inspect(&GitHub.fetch_ref/0) do
    test "returns the GITHUB_REF environment variable" do
      System.put_env("GITHUB_REF", "refs/heads/main")
      assert {:ok, "refs/heads/main"} = GitHub.fetch_ref()
    end

    test "returns :error if GITHUB_REF is not set" do
      assert :error = GitHub.fetch_ref()
    end
  end

  describe inspect(&GitHub.fetch_token/0) do
    test "returns the GITHUB_TOKEN environment variable" do
      System.put_env("GITHUB_TOKEN", "token123")
      assert {:ok, "token123"} = GitHub.fetch_token()
    end

    test "returns :error if GITHUB_TOKEN is not set" do
      assert :error = GitHub.fetch_token()
    end
  end
end
