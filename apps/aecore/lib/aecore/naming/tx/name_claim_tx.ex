defmodule Aecore.Naming.Tx.NameClaimTx do
  @moduledoc """
  Aecore structure of naming claim.
  """

  @behaviour Aecore.Tx.Transaction

  alias Aecore.Chain.ChainState
  alias Aecore.Naming.Tx.NameClaimTx
  alias Aecore.Naming.Naming
  alias Aecore.Naming.NameUtil
  alias Aecore.Account.AccountStateTree
  alias Aecore.Tx.DataTx

  require Logger

  @typedoc "Expected structure for the Claim Transaction"
  @type payload :: %{
          name: String.t(),
          name_salt: Naming.salt()
        }

  @typedoc "Structure that holds specific transaction info in the chainstate.
  In the case of NameClaimTx we have the naming subdomain chainstate."
  @type tx_type_state() :: ChainState.naming()

  @typedoc "Structure of the Spend Transaction type"
  @type t :: %NameClaimTx{
          name: String.t(),
          name_salt: Naming.salt()
        }

  @doc """
  Definition of Aecore NameClaimTx structure

  ## Parameters
  - name: name to be claimed
  - name_salt: salt that the name was pre-claimed with
  """
  defstruct [:name, :name_salt]
  use ExConstructor

  # Callbacks

  @spec init(payload()) :: NameClaimTx.t()
  def init(%{name: name, name_salt: name_salt} = _payload) do
    %NameClaimTx{name: name, name_salt: name_salt}
  end

  @doc """
  Checks name format
  """
  @spec validate(NameClaimTx.t(), DataTx.t()) :: :ok | {:error, String.t()}
  def validate(%NameClaimTx{name: name, name_salt: name_salt}, data_tx) do
    validate_name = NameUtil.normalize_and_validate_name(name)
    senders = DataTx.senders(data_tx)

    cond do
      validate_name |> elem(0) == :error ->
        {:error, "#{__MODULE__}: #{validate_name |> elem(1)}: #{inspect(name)}"}

      byte_size(name_salt) != Naming.get_name_salt_byte_size() ->
        {:error,
         "#{__MODULE__}: Name salt bytes size not correct: #{inspect(byte_size(name_salt))}"}

      length(senders) != 1 ->
        {:error, "#{__MODULE__}: Invalid senders number"}

      true ->
        :ok
    end
  end

  @spec get_chain_state_name :: Naming.chain_state_name()
  def get_chain_state_name, do: :naming

  @doc """
  Claims a name for one account after it was pre-claimed.
  """
  @spec process_chainstate(
          AccountStateTree.accounts_state(),
          tx_type_state(),
          non_neg_integer(),
          NameClaimTx.t(),
          DataTx.t()
        ) :: {AccountStateTree.accounts_state(), tx_type_state()}
  def process_chainstate(
        accounts,
        naming_state,
        block_height,
        %NameClaimTx{} = tx,
        data_tx
      ) do
    sender = DataTx.main_sender(data_tx)

    {:ok, pre_claim_commitment} = Naming.create_commitment_hash(tx.name, tx.name_salt)
    {:ok, claim_hash} = NameUtil.normalized_namehash(tx.name)
    claim = Naming.create_claim(claim_hash, tx.name, sender, block_height)

    updated_naming_chainstate =
      naming_state
      |> Map.delete(pre_claim_commitment)
      |> Map.put(claim_hash, claim)

    {:ok, {accounts, updated_naming_chainstate}}
  end

  @doc """
  Checks whether all the data is valid according to the NameClaimTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check(
          ChainState.accounts(),
          tx_type_state(),
          non_neg_integer(),
          NameClaimTx.t(),
          DataTx.t()
        ) :: :ok
  def preprocess_check(
        accounts,
        naming_state,
        _block_height,
        tx,
        data_tx
      ) do
    sender = DataTx.main_sender(data_tx)
    fee = DataTx.fee(data_tx)
    account_state = AccountStateTree.get(accounts, sender)

    {:ok, pre_claim_commitment} = Naming.create_commitment_hash(tx.name, tx.name_salt)
    pre_claim = Map.get(naming_state, pre_claim_commitment)

    {:ok, claim_hash} = NameUtil.normalized_namehash(tx.name)
    claim = Map.get(naming_state, claim_hash)

    cond do
      account_state.balance - fee < 0 ->
        {:error, "#{__MODULE__}: Negative balance: #{inspect(account_state.balance - fee)}"}

      pre_claim == nil ->
        {:error, "#{__MODULE__}: Name has not been pre-claimed: #{inspect(pre_claim)}"}

      pre_claim.owner != sender ->
        {:error,
         "#{__MODULE__}: Sender is not pre-claim owner: #{inspect(pre_claim.owner)}, #{
           inspect(sender)
         }"}

      claim != nil ->
        {:error, "#{__MODULE__}: Name has aleady been claimed: #{inspect(claim)}"}

      true ->
        :ok
    end
  end

  @spec deduct_fee(
          ChainState.accounts(),
          non_neg_integer(),
          NameCaimTx.t(),
          DataTx.t(),
          non_neg_integer()
        ) :: ChainState.account()
  def deduct_fee(accounts, block_height, _tx, data_tx, fee) do
    DataTx.standard_deduct_fee(accounts, block_height, data_tx, fee)
  end

  @spec is_minimum_fee_met?(SignedTx.t()) :: boolean()
  def is_minimum_fee_met?(tx) do
    tx.data.fee >= Application.get_env(:aecore, :tx_data)[:minimum_fee]
  end
end
