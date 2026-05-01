defmodule FileStore.ErrorTest do
  use ExUnit.Case, async: true

  alias FileStore.Error.Message

  describe "FileStore.NotFound" do
    test "message with key" do
      error = %FileStore.NotFound{operation: :read, key: "foo", reason: :enoent}
      assert Exception.message(error) == ~s|could not read key "foo": no such file or directory|
    end

    test "message for copy" do
      error = %FileStore.NotFound{operation: :copy, src: "src", dest: "dest", reason: :enoent}

      assert Exception.message(error) ==
               ~s|could not copy "src" to "dest": no such file or directory|
    end
  end

  describe "FileStore.PermissionDenied" do
    test "message" do
      error = %FileStore.PermissionDenied{operation: :write, key: "foo", reason: :eacces}
      assert Exception.message(error) == ~s|could not write to key "foo": permission denied|
    end
  end

  describe "FileStore.Conflict" do
    test "message" do
      error = %FileStore.Conflict{operation: :write, key: "foo", reason: :eexist}
      msg = Exception.message(error)
      assert msg =~ ~s|could not write to key "foo"|
      assert msg =~ "file"
    end
  end

  describe "FileStore.InvalidArgument" do
    test "message with :invalid_tags" do
      error = %FileStore.InvalidArgument{operation: :get_tags, key: "foo", reason: :invalid_tags}
      assert Exception.message(error) == ~s|could not get tags for key "foo": :invalid_tags|
    end
  end

  describe "FileStore.Network" do
    test "message with http error" do
      reason = {:http_error, 503, "Service Unavailable"}
      error = %FileStore.Network{operation: :read, key: "foo", reason: reason}
      assert Exception.message(error) == ~s|could not read key "foo": HTTP 503 Server Error|
    end
  end

  describe "FileStore.Error (catch-all)" do
    test "message with unknown reason" do
      error = %FileStore.Error{operation: :read, key: "foo", reason: :some_weird_error}
      assert Exception.message(error) == ~s|could not read key "foo": :some_weird_error|
    end

    test "message with nil operation" do
      error = %FileStore.Error{reason: :boom}
      assert Exception.message(error) == "error: :boom"
    end
  end

  describe "Message.format_reason/1" do
    test "formats known POSIX atoms" do
      assert Message.format_reason(:enoent) == "no such file or directory"
      assert Message.format_reason(:eacces) == "permission denied"
      assert Message.format_reason(:eisdir) == "illegal operation on a directory"
      assert is_binary(Message.format_reason(:eexist))
    end

    test "formats HTTP errors" do
      assert Message.format_reason({:http_error, 400, ""}) == "HTTP 400 Bad Request"
      assert Message.format_reason({:http_error, 401, ""}) == "HTTP 401 Unauthorized"
      assert Message.format_reason({:http_error, 403, ""}) == "HTTP 403 Forbidden"
      assert Message.format_reason({:http_error, 404, ""}) == "HTTP 404 Not Found"
      assert Message.format_reason({:http_error, 409, ""}) == "HTTP 409 Conflict"
      assert Message.format_reason({:http_error, 410, ""}) == "HTTP 410 Gone"
      assert Message.format_reason({:http_error, 412, ""}) == "HTTP 412 Precondition Failed"
      assert Message.format_reason({:http_error, 416, ""}) == "HTTP 416 Range Not Satisfiable"
      assert Message.format_reason({:http_error, 422, ""}) == "HTTP 422 Unprocessable Entity"
      assert Message.format_reason({:http_error, 429, ""}) == "HTTP 429 Too Many Requests"
      assert Message.format_reason({:http_error, 503, ""}) == "HTTP 503 Server Error"
      assert Message.format_reason({:http_error, 418, ""}) =~ "HTTP 418"
    end

    test "formats File.Error via posix reason" do
      e = %File.Error{reason: :enoent, action: "read", path: "/tmp/x"}
      assert Message.format_reason(e) == "no such file or directory"
    end

    test "formats exception structs via Exception.message/1" do
      e = %RuntimeError{message: "something went wrong"}
      assert Message.format_reason(e) == "something went wrong"
    end

    test "falls back to inspect for unknown terms" do
      assert Message.format_reason(:totally_unknown) == ":totally_unknown"
      assert Message.format_reason({:boom, "x"}) == ~s|{:boom, "x"}|
    end
  end

  describe "operation-specific messages" do
    test "delete_all with prefix" do
      error = %FileStore.Error{operation: :delete_all, key: "foo/", reason: :enoent}
      assert Exception.message(error) =~ "delete keys matching prefix"
    end

    test "delete_all without prefix" do
      error = %FileStore.Error{operation: :delete_all, key: nil, reason: :enoent}
      assert Exception.message(error) == "could not delete all keys: no such file or directory"
    end

    test "upload" do
      error = %FileStore.NotFound{operation: :upload, path: "/tmp/x", key: "k", reason: :enoent}
      assert Exception.message(error) =~ "upload file"
      assert Exception.message(error) =~ "no such file or directory"
    end

    test "download" do
      error = %FileStore.NotFound{operation: :download, key: "k", path: "/tmp/x", reason: :enoent}
      assert Exception.message(error) =~ "download key"
    end

    test "set_tags" do
      error = %FileStore.NotFound{
        operation: :set_tags,
        key: "k",
        tags: [{"a", "b"}],
        reason: :enoent
      }

      assert Exception.message(error) =~ "set tags"
    end

    test "get_signed_url" do
      error = %FileStore.Error{operation: :get_signed_url, key: "k", reason: :enoent}
      assert Exception.message(error) =~ "generate signed URL"
    end

    test "delete" do
      error = %FileStore.Error{operation: :delete, key: "foo", reason: :enoent}
      assert Exception.message(error) =~ ~s|delete key "foo"|
    end

    test "put_access_control_list" do
      error = %FileStore.Error{
        operation: :put_access_control_list,
        key: "foo",
        acl: :public_read,
        reason: :enoent
      }

      assert Exception.message(error) =~ "access control list"
    end
  end
end
