defmodule MixDependencySubmission.Submission.JobTest do
  use ExUnit.Case, async: true

  alias MixDependencySubmission.Submission.Job

  doctest Job

  describe "JSON.Encoder" do
    test "encodes filled struct" do
      job = %Job{
        id: "test",
        correlator: "test",
        html_url: URI.parse("http://example.com")
      }

      assert %{"correlator" => "test", "html_url" => "http://example.com", "id" => "test"} =
               job |> JSON.encode!() |> JSON.decode!()
    end

    test "encodes partial struct" do
      job = %Job{
        id: "test",
        correlator: "test"
      }

      assert %{"correlator" => "test", "id" => "test"} =
               job |> JSON.encode!() |> JSON.decode!()
    end
  end
end
