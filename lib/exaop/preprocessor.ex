defmodule Exaop.Preprocessor do
  @moduledoc """
  This module defines the behaviour for external Exaop setters.
  """

  @typep acc :: Exaop.acc()
  @typep args :: Exaop.args()
  @typep params :: Exaop.params()

  @doc """
  Invoked to handle the corresponding `preprocess` step.
  """
  @callback preprocess(params, args, acc) :: {:ok, acc} | {:error, term}
end
