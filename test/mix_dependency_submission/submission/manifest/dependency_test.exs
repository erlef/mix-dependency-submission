defmodule MixDependencySubmission.Submission.Manifest.DependencyTest do
  use ExUnit.Case, async: true

  alias MixDependencySubmission.Submission.Manifest.Dependency

  doctest Dependency

  describe "Jason.Encoder" do
    test "encodes filled struct" do
      dependency = %Dependency{
        package_url: %Purl{type: "hex", name: "gettext"},
        metadata: %{"foo" => "bar"},
        scope: "runtime",
        relationship: "direct",
        dependencies: [
          %Purl{type: "hex", name: "expo"}
        ]
      }

      assert %{
               "dependencies" => ["pkg:hex/expo"],
               "metadata" => %{"foo" => "bar"},
               "package_url" => "pkg:hex/gettext",
               "relationship" => "direct",
               "scope" => "runtime"
             } = dependency |> Jason.encode!() |> Jason.decode!()
    end

    test "encodes empty struct" do
      dependency = %Dependency{}

      assert %{} == dependency |> Jason.encode!() |> Jason.decode!()
    end
  end
end
