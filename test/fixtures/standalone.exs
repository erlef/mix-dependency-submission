alias MixDependencySubmission.ApiClient

{:ok, _apps} = Application.ensure_all_started(:mix_dependency_submission)
{:ok, _apps} = Application.ensure_all_started(:plug)

result = System.fetch_env!("SUBMISSION_TEST_RESULT")

Req.Test.stub(ApiClient, fn conn ->
  status = if result == "HTTP_ERROR", do: :bad_request, else: :created

  conn
  |> Plug.Conn.put_status(status)
  |> Req.Test.json(%{"id" => 123, "message" => "Submission response", "result" => result})
end)

Application.put_env(:mix_dependency_submission, ApiClient, plug: {Req.Test, ApiClient})
System.put_env("__BURRITO", "1")

:ok = :sys.suspend(:global_name_server)
MixDependencySubmission.Application.start(:normal, [])
IO.puts("Application startup returned")
System.halt(99)
