defmodule FileStore.Error.ClassifierTest do
  use ExUnit.Case, async: true

  alias FileStore.Error.Classifier

  defp classify(reason), do: Classifier.classify(reason, operation: :read, key: "k")

  describe "POSIX atoms" do
    test ":enoent → NotFound" do
      assert %FileStore.NotFound{reason: :enoent} = classify(:enoent)
    end

    test ":enotdir → NotFound" do
      assert %FileStore.NotFound{reason: :enotdir} = classify(:enotdir)
    end

    test ":eacces → PermissionDenied" do
      assert %FileStore.PermissionDenied{reason: :eacces} = classify(:eacces)
    end

    test ":eperm → PermissionDenied" do
      assert %FileStore.PermissionDenied{reason: :eperm} = classify(:eperm)
    end

    test ":erofs → PermissionDenied" do
      assert %FileStore.PermissionDenied{reason: :erofs} = classify(:erofs)
    end

    test ":eexist → Conflict" do
      assert %FileStore.Conflict{reason: :eexist} = classify(:eexist)
    end

    test ":eisdir → Conflict" do
      assert %FileStore.Conflict{reason: :eisdir} = classify(:eisdir)
    end

    test ":enotempty → Conflict" do
      assert %FileStore.Conflict{reason: :enotempty} = classify(:enotempty)
    end

    test ":einval → InvalidArgument" do
      assert %FileStore.InvalidArgument{reason: :einval} = classify(:einval)
    end

    test ":enametoolong → InvalidArgument" do
      assert %FileStore.InvalidArgument{reason: :enametoolong} = classify(:enametoolong)
    end

    test ":enospc → Network" do
      assert %FileStore.Network{reason: :enospc} = classify(:enospc)
    end

    test ":eio → Network" do
      assert %FileStore.Network{reason: :eio} = classify(:eio)
    end

    test ":econnrefused → Network" do
      assert %FileStore.Network{reason: :econnrefused} = classify(:econnrefused)
    end
  end

  describe "custom atoms" do
    test ":invalid_tags → InvalidArgument" do
      assert %FileStore.InvalidArgument{reason: :invalid_tags} = classify(:invalid_tags)
    end

    test "unknown atom → Error" do
      assert %FileStore.Error{reason: :totally_unknown} = classify(:totally_unknown)
    end
  end

  describe "HTTP errors" do
    test "401 → PermissionDenied" do
      r = {:http_error, 401, "Unauthorized"}
      assert %FileStore.PermissionDenied{reason: ^r} = classify(r)
    end

    test "403 → PermissionDenied" do
      r = {:http_error, 403, "Forbidden"}
      assert %FileStore.PermissionDenied{reason: ^r} = classify(r)
    end

    test "404 → NotFound" do
      r = {:http_error, 404, "Not Found"}
      assert %FileStore.NotFound{reason: ^r} = classify(r)
    end

    test "410 → NotFound" do
      r = {:http_error, 410, "Gone"}
      assert %FileStore.NotFound{reason: ^r} = classify(r)
    end

    test "409 → Conflict" do
      r = {:http_error, 409, "Conflict"}
      assert %FileStore.Conflict{reason: ^r} = classify(r)
    end

    test "412 → Conflict" do
      r = {:http_error, 412, "Precondition Failed"}
      assert %FileStore.Conflict{reason: ^r} = classify(r)
    end

    test "400 → InvalidArgument" do
      r = {:http_error, 400, "Bad Request"}
      assert %FileStore.InvalidArgument{reason: ^r} = classify(r)
    end

    test "429 → Network" do
      r = {:http_error, 429, "Too Many Requests"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "500 → Network" do
      r = {:http_error, 500, "Internal Server Error"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "503 → Network" do
      r = {:http_error, 503, "Service Unavailable"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "unrecognized status → Error" do
      r = {:http_error, 418, "I'm a Teapot"}
      assert %FileStore.Error{reason: ^r} = classify(r)
    end
  end

  describe "transport tuples" do
    test "{:socket_closed_remotely, _} → Network" do
      r = {:socket_closed_remotely, "info"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "{:closed, _} → Network" do
      r = {:closed, "reason"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "{:timeout, _} → Network" do
      r = {:timeout, :connect}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end

    test "{:nxdomain, _} → Network" do
      r = {:nxdomain, "host"}
      assert %FileStore.Network{reason: ^r} = classify(r)
    end
  end

  describe "exception structs" do
    test "File.Error with :enoent reason → NotFound" do
      r = %File.Error{reason: :enoent, action: "read", path: "/tmp/x"}
      assert %FileStore.NotFound{reason: ^r} = classify(r)
    end

    test "File.Error with :eacces reason → PermissionDenied" do
      r = %File.Error{reason: :eacces, action: "read", path: "/tmp/x"}
      assert %FileStore.PermissionDenied{reason: ^r} = classify(r)
    end

    test "File.Error with unknown reason → Error" do
      r = %File.Error{reason: :some_weird_posix, action: "read", path: "/tmp/x"}
      assert %FileStore.Error{reason: ^r} = classify(r)
    end

    test "arbitrary exception → Error" do
      r = %RuntimeError{message: "boom"}
      assert %FileStore.Error{reason: ^r} = classify(r)
    end
  end

  describe "pass-through for already-classified errors" do
    test "NotFound passes through unchanged" do
      inner = %FileStore.NotFound{reason: :enoent, operation: :copy}
      result = classify(inner)
      assert %FileStore.NotFound{reason: ^inner} = result
    end

    test "Network passes through unchanged" do
      inner = %FileStore.Network{reason: :enospc}
      result = classify(inner)
      assert %FileStore.Network{reason: ^inner} = result
    end
  end

  describe "context fields" do
    test "operation and key are set from ctx" do
      result = Classifier.classify(:enoent, operation: :write, key: "mykey")
      assert %FileStore.NotFound{operation: :write, key: "mykey"} = result
    end

    test "src/dest are set from ctx" do
      result = Classifier.classify(:enoent, operation: :copy, src: "a", dest: "b")
      assert %FileStore.NotFound{operation: :copy, src: "a", dest: "b"} = result
    end
  end
end
