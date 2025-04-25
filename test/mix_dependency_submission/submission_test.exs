defmodule MixDependencySubmission.SubmissionTest do
  use ExUnit.Case, async: true

  alias MixDependencySubmission.Submission

  doctest Submission

  describe "JSON.Encoder" do
    test "encodes filled struct" do
      datetime = DateTime.utc_now()

      submission = %Submission{
        version: 0,
        job: %Submission.Job{
          id: "test",
          correlator: "test",
          html_url: URI.parse("http://example.com")
        },
        sha: "sha",
        ref: "ref",
        detector: %Submission.Detector{
          name: "test",
          version: Version.parse!("1.0.0"),
          url: URI.parse("http://example.com")
        },
        metadata: %{"foo" => "bar"},
        scanned: datetime,
        manifests: %{}
      }

      datetime_string = DateTime.to_iso8601(datetime)

      assert %{
               "detector" => %{"name" => "test", "url" => "http://example.com", "version" => "1.0.0"},
               "job" => %{"correlator" => "test", "html_url" => "http://example.com", "id" => "test"},
               "manifests" => %{},
               "metadata" => %{"foo" => "bar"},
               "ref" => "ref",
               "scanned" => ^datetime_string,
               "sha" => "sha",
               "version" => 0
             } =
               submission |> JSON.encode!() |> JSON.decode!()
    end
  end
end
