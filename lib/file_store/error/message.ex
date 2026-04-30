defmodule FileStore.Error.Message do
  @moduledoc false

  @posix ~w(enoent enotdir eacces eperm erofs eexist eisdir enotempty ebusy etxtbsy
            einval enametoolong eloop enospc eio econnrefused econnreset enetdown
            enetunreach ehostunreach ebadf)a

  def render(%{operation: nil} = e), do: "error: #{format_reason(e.reason)}"

  def render(%{operation: op} = e) do
    "could not #{verb(op, e)}: #{format_reason(e.reason)}"
  end

  def format_reason(r) when r in @posix do
    r |> :file.format_error() |> IO.iodata_to_binary()
  end

  def format_reason({:http_error, status, _}) do
    "HTTP #{status} #{http_phrase(status)}"
  end

  def format_reason(%File.Error{reason: posix}) when posix in @posix do
    posix |> :file.format_error() |> IO.iodata_to_binary()
  end

  def format_reason(%{__exception__: true} = e), do: Exception.message(e)

  def format_reason(other), do: inspect(other)

  defp verb(:read, %{key: k}), do: "read key #{inspect(k)}"
  defp verb(:write, %{key: k}), do: "write to key #{inspect(k)}"
  defp verb(:upload, %{path: p, key: k}), do: "upload file #{inspect(p)} to key #{inspect(k)}"
  defp verb(:download, %{key: k, path: p}), do: "download key #{inspect(k)} to file #{inspect(p)}"
  defp verb(:stat, %{key: k}), do: "read stats for key #{inspect(k)}"
  defp verb(:delete, %{key: k}), do: "delete key #{inspect(k)}"
  defp verb(:delete_all, %{key: nil}), do: "delete all keys"
  defp verb(:delete_all, %{key: prefix}), do: "delete keys matching prefix #{inspect(prefix)}"
  defp verb(:copy, %{src: s, dest: d}), do: "copy #{inspect(s)} to #{inspect(d)}"
  defp verb(:rename, %{src: s, dest: d}), do: "rename #{inspect(s)} to #{inspect(d)}"

  defp verb(:put_access_control_list, %{key: k, acl: a}),
    do: "set the access control list of #{inspect(k)} to #{inspect(a)}"

  defp verb(:set_tags, %{key: k, tags: t}), do: "set tags #{inspect(t)} for key #{inspect(k)}"
  defp verb(:get_tags, %{key: k}), do: "get tags for key #{inspect(k)}"
  defp verb(:get_signed_url, %{key: k}), do: "generate signed URL for key #{inspect(k)}"

  defp http_phrase(400), do: "Bad Request"
  defp http_phrase(401), do: "Unauthorized"
  defp http_phrase(403), do: "Forbidden"
  defp http_phrase(404), do: "Not Found"
  defp http_phrase(409), do: "Conflict"
  defp http_phrase(410), do: "Gone"
  defp http_phrase(412), do: "Precondition Failed"
  defp http_phrase(416), do: "Range Not Satisfiable"
  defp http_phrase(422), do: "Unprocessable Entity"
  defp http_phrase(429), do: "Too Many Requests"
  defp http_phrase(s) when s in 500..599, do: "Server Error"
  defp http_phrase(_), do: ""
end
