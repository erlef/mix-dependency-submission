defmodule MixDependencySubmission.Submission.Manifest.FileTest do
  use ExUnit.Case, async: true

  alias MixDependencySubmission.Submission.Manifest.File

  doctest File

  describe "JSON.Encoder" do
    test "encodes filled struct" do
      file = %File{
        source_location: "mix.exs"
      }

      assert %{"source_location" => "mix.exs"} = file |> JSON.encode!() |> JSON.decode!()
    end

    test "encodes empty struct" do
      file = %File{}

      assert %{} == file |> JSON.encode!() |> JSON.decode!()
    end
  end
end
