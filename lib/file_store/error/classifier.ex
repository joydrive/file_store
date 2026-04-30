defmodule FileStore.Error.Classifier do
  @moduledoc false

  alias FileStore.{Conflict, Error, InvalidArgument, Network, NotFound, PermissionDenied}

  @not_found ~w(enoent enotdir)a
  @permission ~w(eacces eperm erofs)a
  @conflict ~w(eexist eisdir enotempty ebusy etxtbsy)a
  @invalid ~w(einval enametoolong eloop)a
  @network ~w(enospc eio econnrefused econnreset enetdown enetunreach ehostunreach)a

  @spec classify(term(), keyword()) :: struct()
  def classify(reason, ctx) do
    {mod, reason} = categorize(reason)
    struct(mod, Keyword.put(ctx, :reason, reason))
  end

  defp categorize(r) when r in @not_found, do: {NotFound, r}
  defp categorize(r) when r in @permission, do: {PermissionDenied, r}
  defp categorize(r) when r in @conflict, do: {Conflict, r}
  defp categorize(r) when r in @invalid, do: {InvalidArgument, r}
  defp categorize(r) when r in @network, do: {Network, r}

  defp categorize(:invalid_tags), do: {InvalidArgument, :invalid_tags}

  defp categorize({:http_error, s, _} = r) when s in [401, 403], do: {PermissionDenied, r}
  defp categorize({:http_error, s, _} = r) when s in [404, 410], do: {NotFound, r}
  defp categorize({:http_error, s, _} = r) when s in [409, 412], do: {Conflict, r}
  defp categorize({:http_error, s, _} = r) when s in [400, 416, 422], do: {InvalidArgument, r}
  defp categorize({:http_error, 429, _} = r), do: {Network, r}
  defp categorize({:http_error, s, _} = r) when s >= 500, do: {Network, r}
  defp categorize({:http_error, _, _} = r), do: {Error, r}

  defp categorize({:socket_closed_remotely, _} = r), do: {Network, r}
  defp categorize({:closed, _} = r), do: {Network, r}
  defp categorize({:timeout, _} = r), do: {Network, r}
  defp categorize({:nxdomain, _} = r), do: {Network, r}

  defp categorize(%mod{} = r)
       when mod in [Error, NotFound, PermissionDenied, Conflict, InvalidArgument, Network],
       do: {mod, r}

  defp categorize(%File.Error{reason: posix} = r) do
    case categorize(posix) do
      {Error, _} -> {Error, r}
      {category, _} -> {category, r}
    end
  end

  defp categorize(%{__exception__: true} = r), do: {Error, r}

  defp categorize(other), do: {Error, other}
end
