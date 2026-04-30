defmodule FileStore.NotFound do
  @moduledoc "Returned when the requested key does not exist in the store."

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end

defmodule FileStore.PermissionDenied do
  @moduledoc "Returned when the caller lacks permission to perform the operation."

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end

defmodule FileStore.Conflict do
  @moduledoc """
  Returned when the operation conflicts with the current resource state.

  Examples: writing to a path where a directory exists, copying to an
  existing key that conflicts, S3 precondition failures.
  """

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end

defmodule FileStore.InvalidArgument do
  @moduledoc "Returned when the caller supplied an invalid or malformed argument."

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end

defmodule FileStore.Network do
  @moduledoc """
  Returned on transport or connectivity failures.

  Pattern-matching on this struct is useful for implementing retry logic.
  """

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end

defmodule FileStore.Error do
  @moduledoc """
  Catch-all error returned when the failure cannot be classified into a
  more specific category. Inspect the `:reason` field for the raw underlying
  cause from the adapter.
  """

  alias FileStore.Error.Message

  defexception [:reason, :operation, :key, :src, :dest, :path, :tags, :acl]

  @impl true
  def message(e), do: Message.render(e)
end
