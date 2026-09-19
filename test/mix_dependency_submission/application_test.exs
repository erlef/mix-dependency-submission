defmodule MixDependencySubmission.ApplicationTest do
  use MixDependencySubmission.EnvCase, async: false

  for {result, expected_status, expected_log} <- [
        {"SUCCESS", 0, "Successfully submitted submission: SUCCESS"},
        {"ACCEPTED", 0, "Successfully submitted submission: ACCEPTED"},
        {"INVALID", 1, "Invalid submission"},
        {"HTTP_ERROR", 2, "Unexpected response"}
      ] do
    @tag :tmp_dir
    test "standalone application halts after #{result}", %{tmp_dir: tmp_dir} do
      github_output = Path.join(tmp_dir, "github_output")
      script = Path.expand("../fixtures/standalone.exs", __DIR__)
      code_paths = Enum.flat_map(:code.get_path(), &["-pa", List.to_string(&1)])

      args =
        code_paths ++
          [
            "-noshell",
            "-eval",
            "application:ensure_all_started(elixir), " <>
              "'Elixir.Code':eval_file(unicode:characters_to_binary(os:getenv(\"SUBMISSION_TEST_SCRIPT\"))).",
            "-extra",
            "--project-path=#{tmp_dir}",
            "--github-token=token",
            "--github-repository=local/test",
            "--github-job-id=test",
            "--github-workflow=test",
            "--sha=sha",
            "--ref=refs/heads/main"
          ]

      erl = System.find_executable("erl")

      {output, status} =
        System.cmd(erl, args,
          stderr_to_stdout: true,
          env: [
            {"SUBMISSION_TEST_SCRIPT", script},
            {"SUBMISSION_TEST_RESULT", unquote(result)},
            {"GITHUB_OUTPUT", github_output},
            {"__BURRITO", nil}
          ]
        )

      assert status == unquote(expected_status), output
      assert output =~ unquote(expected_log)
      refute output =~ "Application startup returned"
      assert File.read!(github_output) =~ "submission-json-path="
    end
  end
end
