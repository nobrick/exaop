defmodule Exaop.Checker do
  @moduledoc """
  This module defines the behaviour for external Exaop checkers.
  """

  @typep acc :: Exaop.acc()
  @typep args :: Exaop.args()
  @typep params :: Exaop.params()

  @doc """
  Invoked to handle the corresponding `check` step.

  Returning `:ok` continues the reduction with the current `params` and `acc`
  passed to the next Exaop step.

  Returning a two-element tuple `{:error, reason}` halts the reduction and the
  built function `__inject__/3` returns the error tuple.

  When the final reduction step is `check` and it returns `:ok`, the built
  function `__inject__/3` returns the last `acc` accumulator.
  """
  @callback check(params, args, acc) :: :ok | {:error, term}
end
