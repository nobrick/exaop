defmodule Exaop.Setter do
  @moduledoc """
  This module defines the behaviour for external Exaop setters.
  """

  @typep acc :: Exaop.acc()
  @typep args :: Exaop.args()
  @typep params :: Exaop.params()

  @doc """
  Invoked to handle the corresponding `set` step.

  The reduction continues with the return value `acc` as the new accumulator
  and the given `params` passed to the next Exaop step.

  When the final reduction step is `set`, the built function `__inject__/3`
  returns its return value `acc` as the accumulator.
  """
  @callback set(params, args, acc) :: acc
end
