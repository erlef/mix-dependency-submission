defmodule MixDependencySubmission.CLI.SubmitTest do
  use MixDependencySubmission.EnvCase, async: false
  use MixDependencySubmission.FixtureCase, async: false

  import ExUnit.CaptureLog

  alias MixDependencySubmission.ApiClient
  alias MixDependencySubmission.CLI.Submit

  doctest Submit, except: [run: 1]

  describe inspect(&Submit.run/2) do
    @tag :tmp_dir
    @tag fixture_app: "app_library"
    test "submits and handles SUCCESS", %{app_path: app_path} do
      github_out = Path.join(app_path, "github_out.txt")
      System.put_env("GITHUB_OUTPUT", github_out)

      response = %{
        "id" => 123,
        "message" => "Submission accepted",
        "result" => "SUCCESS"
      }

      Req.Test.stub(ApiClient, fn conn ->
        conn
        |> Plug.Conn.put_status(:created)
        |> Req.Test.json(response)
      end)

      logs =
        capture_log(fn ->
          assert 0 =
                   Submit.run([
                     "--project-path",
                     app_path,
                     "--github-job-id",
                     "job123",
                     "--github-workflow",
                     "workflow job123",
                     "--github-repository",
                     "erlef/mix-dependency-submission",
                     "--sha",
                     "sha",
                     "--ref",
                     "ref",
                     "--github-token",
                     "token"
                   ])
        end)

      assert %{
               "submission-json-path" => submission_json_path,
               "snapshot-id" => "123",
               "snapshot-api-url" =>
                 "https://api.github.com/repos/erlef/mix-dependency-submission/dependency-graph/snapshots/123"
             } = read_github_out(github_out)

      assert logs =~ "Calculated Submission, written to: #{submission_json_path}"
      assert logs =~ "Successfully submitted submission: SUCCESS: Submission accepted"
      assert logs =~ "Success Response: #{inspect(response)}"

      assert %{
               "detector" => %{
                 "name" => "mix_dependency_submission",
                 "url" => "https://github.com/erlef/mix-dependency-submission",
                 "version" => _version
               },
               "job" => %{"correlator" => "workflow job123 job123", "id" => "job123"},
               "manifests" => %{},
               "metadata" => %{},
               "ref" => "ref",
               "scanned" => _scanned_at,
               "sha" => "sha",
               "version" => 0
             } = submission_json_path |> File.read!() |> JSON.decode!()
    end

    @tag :tmp_dir
    @tag fixture_app: "app_library"
    test "submits and handles INVALID", %{app_path: app_path} do
      github_out = Path.join(app_path, "github_out.txt")
      System.put_env("GITHUB_OUTPUT", github_out)

      response = %{"id" => 123, "message" => "Something is wrong", "result" => "INVALID"}

      Req.Test.stub(ApiClient, fn conn ->
        conn
        |> Plug.Conn.put_status(:created)
        |> Req.Test.json(response)
      end)

      logs =
        capture_log(fn ->
          assert 1 =
                   Submit.run([
                     "--project-path",
                     app_path,
                     "--github-job-id",
                     "job123",
                     "--github-workflow",
                     "workflow job123",
                     "--github-repository",
                     "erlef/mix-dependency-submission",
                     "--sha",
                     "sha",
                     "--ref",
                     "ref",
                     "--github-token",
                     "token"
                   ])
        end)

      assert %{
               "submission-json-path" => submission_json_path,
               "snapshot-id" => "123",
               "snapshot-api-url" =>
                 "https://api.github.com/repos/erlef/mix-dependency-submission/dependency-graph/snapshots/123"
             } = read_github_out(github_out)

      assert logs =~ "Calculated Submission, written to: #{submission_json_path}"
      assert logs =~ "Invalid submission: Something is wrong"
      assert logs =~ "Invalid Response: #{inspect(response)}"

      assert %{
               "detector" => %{
                 "name" => "mix_dependency_submission",
                 "url" => "https://github.com/erlef/mix-dependency-submission",
                 "version" => _version
               },
               "job" => %{"correlator" => "workflow job123 job123", "id" => "job123"},
               "manifests" => %{},
               "metadata" => %{},
               "ref" => "ref",
               "scanned" => _scanned_at,
               "sha" => "sha",
               "version" => 0
             } = submission_json_path |> File.read!() |> JSON.decode!()
    end

    @tag :tmp_dir
    @tag fixture_app: "app_library"
    test "submits and handles unexpected response", %{app_path: app_path} do
      github_out = Path.join(app_path, "github_out.txt")
      System.put_env("GITHUB_OUTPUT", github_out)

      response = %{"something" => "is wrong"}

      Req.Test.stub(ApiClient, fn conn ->
        conn
        |> Plug.Conn.put_status(:internal_server_error)
        |> Req.Test.json(response)
      end)

      logs =
        capture_log(fn ->
          assert 2 =
                   Submit.run([
                     "--project-path",
                     app_path,
                     "--github-job-id",
                     "job123",
                     "--github-workflow",
                     "workflow job123",
                     "--github-repository",
                     "erlef/mix-dependency-submission",
                     "--sha",
                     "sha",
                     "--ref",
                     "ref",
                     "--github-token",
                     "token"
                   ])
        end)

      assert %{"submission-json-path" => submission_json_path} = read_github_out(github_out)

      assert logs =~ "Calculated Submission, written to: #{submission_json_path}"

      assert logs =~
               "Unexpected response: #{inspect(%Req.Response{status: 500, headers: %{"cache-control" => ["max-age=0, private, must-revalidate"], "content-type" => ["application/json; charset=utf-8"]}, body: response, trailers: %{}, private: %{}},
               pretty: true)}"

      assert %{
               "detector" => %{
                 "name" => "mix_dependency_submission",
                 "url" => "https://github.com/erlef/mix-dependency-submission",
                 "version" => _version
               },
               "job" => %{"correlator" => "workflow job123 job123", "id" => "job123"},
               "manifests" => %{},
               "metadata" => %{},
               "ref" => "ref",
               "scanned" => _scanned_at,
               "sha" => "sha",
               "version" => 0
             } = submission_json_path |> File.read!() |> JSON.decode!()
    end
  end

  @spec read_github_out(String.t()) :: map()
  defp read_github_out(github_out) do
    github_out
    |> File.stream!()
    |> Map.new(fn line ->
      [key, value] = String.split(line, "=", parts: 2)
      {String.trim(key), String.trim(value)}
    end)
  end
end
