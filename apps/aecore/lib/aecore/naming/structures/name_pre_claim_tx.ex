defmodule Aecore.Naming.Structures.NamePreClaimTx do
  @moduledoc """
  Aecore structure of naming pre claim data.
  """

  @behaviour Aecore.Structures.Transaction

  alias Aecore.Chain.ChainState
  alias Aecore.Naming.Structures.NamePreClaimTx
  alias Aecore.Naming.Naming
  alias Aecore.Structures.Account

  require Logger

  @type commitment_hash :: binary()

  @typedoc "Expected structure for the Pre Claim Transaction"
  @type payload :: %{
          commitment: commitment_hash()
        }

  @typedoc "Structure that holds specific transaction info in the chainstate.
  In the case of NamePreClaimTx we don't have a subdomain chainstate."
  @type tx_type_state() :: ChainState.naming()

  @typedoc "Structure of the Spend Transaction type"
  @type t :: %NamePreClaimTx{
          commitment: commitment_hash()
        }

  @doc """
  Definition of Aecore NamePreClaimTx structure

  ## Parameters
  - commitment: hash of the commitment for name claiming
  """
  defstruct [:commitment]
  use ExConstructor

  # Callbacks

  @spec init(payload()) :: NamePreClaimTx.t()
  def init(%{commitment: commitment} = _payload) do
    %NamePreClaimTx{commitment: commitment}
  end

  @doc """
  Checks commitment hash byte size
  """
  @spec is_valid?(NamePreClaimTx.t()) :: boolean()
  def is_valid?(%NamePreClaimTx{commitment: _commitment}) do
    # TODO validate commitment byte size
    true
  end

  @spec get_chain_state_name() :: Naming.chain_state_name()
  def get_chain_state_name(), do: :naming

  @doc """
  Changes the account state (balance) of the sender and receiver.
  """
  @spec process_chainstate!(
          NamePreClaimTx.t(),
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          block_height :: non_neg_integer(),
          ChainState.account(),
          tx_type_state()
        ) :: {ChainState.accounts(), tx_type_state()}
  def process_chainstate!(
        %NamePreClaimTx{} = tx,
        sender,
        fee,
        nonce,
        block_height,
        accounts,
        naming
      ) do
    case preprocess_check(tx, accounts[sender], sender, fee, nonce, block_height, naming) do
      :ok ->
        new_senderount_state =
          accounts[sender]
          |> deduct_fee(fee)
          |> Account.transaction_out_nonce_update(nonce)

        updated_accounts_chainstate = Map.put(accounts, sender, new_senderount_state)
        account_naming = Map.get(naming, sender, Naming.empty())

        updated_naming_pre_claims = [
          Naming.create_pre_claim(block_height, tx.commitment) | account_naming.pre_claims
        ]

        updated_naming_chainstate =
          Map.put(naming, sender, %{account_naming | pre_claims: updated_naming_pre_claims})

        {updated_accounts_chainstate, updated_naming_chainstate}

      {:error, _reason} = err ->
        throw(err)
    end
  end

  @doc """
  Checks whether all the data is valid according to the NamePreClaimTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check(
          NamePreClaimTx.t(),
          ChainState.account(),
          Wallet.pubkey(),
          non_neg_integer(),
          non_neg_integer(),
          block_height :: non_neg_integer(),
          tx_type_state()
        ) :: :ok | {:error, DataTx.reason()}
  def preprocess_check(_tx, account_state, _sender, fee, nonce, _block_height, _naming) do
    cond do
      account_state.balance - fee < 0 ->
        {:error, "Negative balance"}

      account_state.nonce >= nonce ->
        {:error, "Nonce too small"}

      true ->
        :ok
    end
  end

  @spec deduct_fee(ChainState.account(), tx_type_state()) :: ChainState.account()
  def deduct_fee(account_state, fee) do
    new_balance = account_state.balance - fee
    Map.put(account_state, :balance, new_balance)
  end
end