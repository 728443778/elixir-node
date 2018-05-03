defmodule Aecore.Naming.NamingStateTree do
  alias Aecore.Naming.Naming
  alias Aeutil.PatriciaMerkleTree

  @type namings_state() :: Trie.t()

  @spec init_empty() :: Trie.t()
  def init_empty do
    PatriciaMerkleTree.new(:naming)
  end

  @spec put(namings_state(), binary(), Naming.t()) :: namings_state()
  def put(trie, key, value) do
    serialized = serialize(value)
    PatriciaMerkleTree.enter(trie, key, serialized)
  end

  @spec get(namings_state(), binary()) :: Naming.t()
  def get(trie, key) do
    {:ok, value} = PatriciaMerkleTree.lookup(trie, key)
    deserialize(value)
  end

  @spec delete(Trie.t(), binary()) :: Trie.t()
  def delete(trie, key) do
    PatriciaMerkleTree.delete(trie, key)
  end

  defp serialize(term) do
    # Must be done using RPL encoding when is done GH-335
    :erlang.term_to_binary(term)
  end

  defp deserialize(binary) do
    # Must be done using RPL dencoding when is done GH-335
    :erlang.binary_to_term(binary)
  end
end
