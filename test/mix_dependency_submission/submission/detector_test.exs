defmodule MixDependencySubmission.Submission.DetectorTest do
  use ExUnit.Case, async: true

  alias MixDependencySubmission.Submission.Detector

  doctest Detector

  describe "Jason.Encoder" do
    test "encodes filled struct" do
      detector = %Detector{
        name: "test",
        version: Version.parse!("1.0.0"),
        url: URI.parse("http://example.com")
      }

      assert %{"name" => "test", "url" => "http://example.com", "version" => "1.0.0"} =
               detector |> Jason.encode!() |> Jason.decode!()
    end
  end
end
