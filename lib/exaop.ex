defmodule Exaop do
  @moduledoc """
  A minimal library for aspect-oriented programming.
  """

  @type acc :: map | struct
  @type args :: term
  @type params :: term

  defmacro __using__(_opts) do
    import Module, only: [register_attribute: 3]

    quote do
      register_attribute(__MODULE__, :exaop_callbacks, accumulate: true)

      @before_compile unquote(__MODULE__)
      @behaviour __MODULE__.ExaopBehaviour

      import unquote(__MODULE__)
      alias __MODULE__.ExaopBehaviour
    end
  end

  defmacro __before_compile__(%{module: module}) do
    all_callbacks =
      module
      |> Module.get_attribute(:exaop_callbacks)
      |> Enum.reverse()

    local_callbacks =
      Enum.filter(all_callbacks, fn
        {{^module, _, _}, _, _} -> true
        _ -> false
      end)

    [
      compile_callbacks(local_callbacks),
      compile_injector(module, all_callbacks)
    ]
  end

  defmacro check(target, args \\ nil, opts \\ []) do
    operate(:check, target, args, opts)
  end

  defmacro preprocess(target, args \\ nil, opts \\ []) do
    operate(:preprocess, target, args, opts)
  end

  defmacro set(target, args \\ nil, opts \\ []) do
    operate(:set, target, args, opts)
  end

  @doc false
  def mfa(target, args, caller, type, opts) do
    wrapped_args = [:params, args, :acc]

    target
    |> Atom.to_string()
    |> match_mfa(target, wrapped_args, caller, type, opts)
  end

  defp match_mfa("Elixir." <> _, target, args, _caller, type, _opts) do
    {target, type, args}
  end

  defp match_mfa("_" <> name, _target, args, caller, type, _opts) do
    function = :"_#{type}_#{name}"
    {caller, function, args}
  end

  defp match_mfa(name, _target, args, caller, type, _opts) do
    function = :"#{type}_#{name}"
    {caller, function, args}
  end

  @doc false
  def invalid_match_message(module, fun, op, invalid_match) do
    valid_ret =
      case op do
        :check ->
          ":ok or {:error, _}"

        :preprocess ->
          "{:ok, _acc} or {:error, _}"
      end

    "#{module}.#{fun}/3 expects #{valid_ret} as" <>
      " return values, got: #{inspect(invalid_match)}"
  end

  ## Helpers

  defp compile_callbacks(local_callbacks) do
    quote bind_quoted: [
            local_callbacks: escape(local_callbacks)
          ] do
      defmodule ExaopBehaviour do
        @type acc :: Exaop.acc()
        @type args :: Exaop.args()
        @type params :: Exaop.params()

        Enum.each(local_callbacks, fn {{caller, fun, args}, op, _opts} ->
          case op do
            :set ->
              @callback unquote(fun)(params, args, acc) :: acc

            :preprocess ->
              @callback unquote(fun)(params, args, acc) :: {:ok, acc} | {:error, term}

            :check ->
              @callback unquote(fun)(params, args, acc) :: :ok | {:error, term}
          end
        end)
      end
    end
  end

  defp compile_injector(module, all_callbacks) do
    quote bind_quoted: [
            all_callbacks: escape(all_callbacks),
            module: module
          ] do
      @exaop_callbacks_ordered all_callbacks

      @doc false
      def __inject__(params, initial_acc) do
        Enum.reduce_while(@exaop_callbacks_ordered, initial_acc, fn
          {{module, fun, [:params, args, :acc]}, op, _opts}, acc ->
            case {op, apply(module, fun, [params, args, acc])} do
              {:set, new_acc} ->
                {:cont, new_acc}

              {:preprocess, {:ok, new_acc}} ->
                {:cont, new_acc}

              {:preprocess, {:error, _} = error} ->
                {:halt, error}

              {:check, :ok} ->
                {:cont, acc}

              {:check, {:error, _} = error} ->
                {:halt, error}

              {op, invalid_match} when op in [:check, :preprocess] ->
                msg = invalid_match_message(module, fun, op, invalid_match)
                raise ArgumentError, msg
            end
        end)
      end

      @doc false
      def __exaop_callbacks__ do
        @exaop_callbacks_ordered
      end
    end
  end

  defp escape(expr) do
    Macro.escape(expr, unquote: true)
  end

  defp operate(op, target, args, opts) do
    quote bind_quoted: [
            args: args,
            injector: __MODULE__,
            op: op,
            opts: opts,
            target: target
          ] do
      mfa = mfa(target, args, __MODULE__, op, opts)
      @exaop_callbacks {mfa, op, opts}
    end
  end
end
