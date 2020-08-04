defmodule ExaopSpec do
  use ESpec

  import Code,
    only: [
      compile_string: 1,
      compiler_options: 1,
      eval_string: 1
    ]

  before_all do
    compiler_options(ignore_module_conflict: true)
  end

  after_all do
    compiler_options(ignore_module_conflict: false)
  end

  describe "Exaop" do
    let :mod do
      rand_module_name()
    end

    let :external_set_mod do
      rand_module_name("BarSet")
    end

    let :external_check_mod do
      rand_module_name("BarCheck")
    end

    let :external_code do
      """
        defmodule #{external_set_mod()} do
          @behaviour Exaop.Setter

          @impl true
          def set(_params, _args, acc), do: acc
        end

        defmodule #{external_check_mod()} do
          @behaviour Exaop.Checker

          @impl true
          def check(_params, _args, _acc), do: :ok
        end
      """
    end

    let :code do
      """
        defmodule #{mod()} do
          use Exaop

          #{definitions()}
          #{implementations()}
        end
      """
    end

    it "warns on unimplemented callbacks" do
      output =
        capture_err(:compile, """
          defmodule Foo do
            use Exaop

            check(:step_1)
            set(:step_2)
            set(:step_3)
            check(:step_4)

            @impl true
            def check_step_1(_params, _args, _acc), do: :ok

            @impl true
            def set_step_3(_params, _args, acc), do: acc
          end
        """)

      message =
        "required by behaviour Foo.ExaopBehaviour is not implemented" <>
          " (in module Foo)"

      expect(output |> to(match("set_step_2/3 " <> message)))
      expect(output |> to(match("check_step_4/3 " <> message)))

      expect(output |> not_to(match("check_step_1/3 ")))
      expect(output |> not_to(match("set_step_3/3 ")))
    end

    it "does not warn when all required callbacks are implemented" do
      output =
        capture_err(:compile, """
          defmodule Foo do
            use Exaop

            check(:step_1)
            set(:step_2)

            @impl true
            def check_step_1(_params, _args, _acc), do: :ok

            @impl true
            def set_step_2(_params, _args, acc), do: acc
          end
        """)

      expect(output |> to(eq("")))
    end

    it "evaluates each macro arguments only once" do
      output =
        capture_io(fn ->
          compile_string("""
            defmodule Foo do
              use Exaop

              import Kernel, except: [inspect: 1]
              import IO, only: [inspect: 1]

              step_1_var = inspect(:step_1)
              step_2_fun = fn -> inspect(:step_2) end

              check(step_1_var)
              set(step_2_fun.())
              set(inspect(:step_3), inspect(:step_3_args))
              check(inspect(:step_4), inspect(:step_4_args))

              check(
                inspect(:step_5),
                inspect(:step_5_args),
                inspect(step_5_opt_key: 0)
              )

              set(
                inspect(:step_6),
                inspect(:step_6_args),
                inspect(step_6_opt_key: 0)
              )

              @impl true
              def check_step_1(_params, _args, _acc), do: :ok

              @impl true
              def check_step_4(_params, _args, _acc), do: {:error, :halt}

              @impl true
              def check_step_5(_params, _args, _acc), do: :ok

              @impl true
              def set_step_2(_params, _args, acc), do: acc

              @impl true
              def set_step_3(_params, _args, acc), do: acc

              @impl true
              def set_step_6(_params, _args, acc), do: acc
            end
          """)
        end)

      expect(
        output
        |> String.split("\n", trim: true)
        |> Enum.sort()
        |> to(
          eq([
            ":step_1",
            ":step_2",
            ":step_3",
            ":step_3_args",
            ":step_4",
            ":step_4_args",
            ":step_5",
            ":step_5_args",
            ":step_6",
            ":step_6_args",
            "[step_5_opt_key: 0]",
            "[step_6_opt_key: 0]"
          ])
        )
      )
    end

    describe "__inject__/2" do
      describe "check" do
        context "with internal checks only" do
          let :call do
            """
              params = %{}
              acc = %{foo: :bar}
              ret = #{mod()}.__inject__(params, acc)
            """
          end

          let :definitions do
            """
              set(:step_1)
              check(:step_2)
              set(:step_3)
              check(:step_4)
            """
          end

          context "when all checks return :ok" do
            let :implementations do
              """
                @impl true
                def set_step_1(_params, _args, acc), do: acc

                @impl true
                def check_step_2(_params, _args, _acc), do: :ok

                @impl true
                def set_step_3(_params, _args, acc) do
                  put_in(acc[:foo], :step_3)
                end

                @impl true
                def check_step_4(_params, _args, _acc), do: :ok
              """
            end

            it "returns the final accumulator" do
              {value, _binding} = eval_string(code() <> call())
              expect(value |> to(eq(%{foo: :step_3})))
            end
          end

          context "when a check returns {:error, _}" do
            let :implementations do
              """
                @impl true
                def set_step_1(_params, _args, acc), do: acc

                @impl true
                def check_step_2(_params, _args, acc), do: {:error, acc}

                @impl true
                def set_step_3(_params, _args, _acc) do
                  raise("Should not be here.")
                end

                @impl true
                def check_step_4(_params, _args, _acc), do: :ok
              """
            end

            it "aborts" do
              {value, _binding} = eval_string(code() <> call())
              expect(value |> to(eq({:error, %{foo: :bar}})))
            end
          end

          context "when a check returns anything other than :ok and {:error, _}" do
            let :implementations do
              """
                @impl true
                def set_step_1(_params, _args, acc), do: acc

                @impl true
                def check_step_2(_params, _args, _acc) do
                  {:error, :invalid_return, 0}
                end

                @impl true
                def set_step_3(_params, _args, _acc) do
                  raise("Should not be here.")
                end

                @impl true
                def check_step_4(_params, _args, _acc), do: :ok
              """
            end

            it "raises an error" do
              fun = fn -> eval_string(code() <> call()) end
              expect(fun |> to(raise_exception(ArgumentError)))
            end
          end
        end

        context "with external checks" do
          let :call do
            """
              params = :foo
              acc = %{foo: :bar}
              ret = #{mod()}.__inject__(params, acc)
            """
          end

          let :definitions do
            """
              set(:step_1)
              check(#{external_check_mod()})
              set(:step_3)
            """
          end

          let :implementations do
            """
              @impl true
              def set_step_1(_params, _args, acc), do: acc

              @impl true
              def set_step_3(params, _args, acc) do
                acc
                |> put_in([:params], params)
                |> put_in([:foo], :step_3)
              end
            """
          end

          context "when all checks return :ok" do
            let :external_code do
              """
                defmodule #{external_check_mod()} do
                  @behaviour Exaop.Checker

                  @impl true
                  def check(_params, _args, _acc), do: :ok
                end
              """
            end

            it "returns the final accumulator" do
              string = external_code() <> code() <> call()
              {value, _binding} = eval_string(string)
              expect(value |> to(eq(%{foo: :step_3, params: :foo})))
            end
          end

          context "when a check returns {:error, _}" do
            let :external_code do
              """
                defmodule #{external_check_mod()} do
                  @behaviour Exaop.Checker

                  @impl true
                  def check(_params, _args, acc), do: {:error, acc}
                end
              """
            end

            it "aborts" do
              string = external_code() <> code() <> call()
              {value, _binding} = eval_string(string)
              expect(value |> to(eq({:error, %{foo: :bar}})))
            end
          end

          context "when a check returns anything other than :ok and {:error, _}" do
            let :external_code do
              """
                defmodule #{external_check_mod()} do
                  @behaviour Exaop.Checker

                  @impl true
                  def check(_params, _args, acc) do
                    {:error, :invalid_return, acc}
                  end
                end
              """
            end

            it "raises an error" do
              fun = fn ->
                string = external_code() <> code() <> call()
                eval_string(string)
              end

              expect(fun |> to(raise_exception(ArgumentError)))
            end
          end
        end
      end

      describe "set" do
        let :call do
          """
            params = %{}
            acc = %{foo: 0, bar: 0}
            ret = #{mod()}.__inject__(params, acc)
          """
        end

        let :definitions do
          """
            set(#{external_set_mod()})
            set(:step_1)
            set(:step_2)
            set(:step_3)
            set(#{external_set_mod_2()})
          """
        end

        let :external_code do
          """
            defmodule #{external_set_mod()} do
              @behaviour Exaop.Setter

              @impl true
              def set(_params, _args, acc) do
                update_in(acc[:foo], & &1 + 6)
              end
            end

            defmodule #{external_set_mod_2()} do
              @behaviour Exaop.Setter

              @impl true
              def set(_params, _args, acc) do
                update_in(acc[:foo], & &1 * 2)
              end
            end
          """
        end

        let :external_set_mod_2 do
          rand_module_name("BarSet")
        end

        let :implementations do
          """
            @impl true
            def set_step_1(_params, _args, acc) do
              put_in(acc[:bar], 1)
            end

            @impl true
            def set_step_2(_params, _args, acc) do
              update_in(acc[:bar], & &1 * 2)
            end

            @impl true
            def set_step_3(_params, _args, acc) do
              update_in(acc[:bar], & &1 + 10)
            end
          """
        end

        it "sets the accumulator" do
          string = external_code() <> code() <> call()
          {value, _binding} = eval_string(string)
          expect(value |> to(eq(%{foo: 12, bar: 12})))
        end
      end
    end

    describe "__exaop_callbacks__/0" do
      let :definitions do
        """
          set(:step_1)
          set(:step_2, :args_2)
          check(:step_3)
          check(:step_4, foo: 0)
          check(:step_5, :args_5, bar: 1)
          set(:step_6, [foo: 1], bar: 0)
          check(#{external_check_mod()})
          set(#{external_set_mod()}, bar: 1)
        """
      end

      let :implementations do
        """
          @impl true
          def set_step_1(_params, _args, acc), do: acc

          @impl true
          def set_step_2(_params, _args, acc), do: put_in(acc["foo"], 0)

          @impl true
          def check_step_3(_params, _args, _acc), do: {:error, :bar}

          @impl true
          def check_step_4(_params, _args, _acc), do: :ok

          @impl true
          def check_step_5(_params, _args, _acc), do: :ok

          @impl true
          def set_step_6(_params, _args, acc), do: acc
        """
      end

      it "returns the list of exaop callbacks" do
        mod = mod()
        mod_atom = to_module_atom(mod)

        external_set_mod = external_set_mod()
        external_set_mod_atom = to_module_atom(external_set_mod)

        external_check_mod = external_check_mod()
        external_check_mod_atom = to_module_atom(external_check_mod)

        {value, _binding} =
          eval_string("""
            function_exported = fn ->
              name = :__exaop_callbacks__
              :erlang.function_exported(#{mod}, name, 0)
            end

            defined_before? = function_exported.()

            #{external_code()}
            #{code()}

            ret = #{mod}.__exaop_callbacks__()
            {defined_before?, function_exported.(), ret}
          """)

        p = &[:params, &1, :acc]

        expected_ret = [
          {{mod_atom, :set_step_1, p.(nil)}, :set, []},
          {{mod_atom, :set_step_2, p.(:args_2)}, :set, []},
          {{mod_atom, :check_step_3, p.(nil)}, :check, []},
          {{mod_atom, :check_step_4, p.(foo: 0)}, :check, []},
          {{mod_atom, :check_step_5, p.(:args_5)}, :check, [bar: 1]},
          {{mod_atom, :set_step_6, p.(foo: 1)}, :set, [bar: 0]},
          {{external_check_mod_atom, :check, p.(nil)}, :check, []},
          {{external_set_mod_atom, :set, p.(bar: 1)}, :set, []}
        ]

        expect(value |> to(eq({false, true, expected_ret})))
      end
    end
  end

  def capture_err(fun) do
    capture_io(:stderr, fun)
  end

  def capture_err(:compile, string) do
    capture_err(fn -> compile_string(string) end)
  end

  def capture_err(:eval, string) do
    capture_err(fn -> eval_string(string) end)
  end

  def rand_module_name(prefix \\ "Foo") do
    number = Enum.random(1..1000_000_000)
    prefix <> to_string(number)
  end

  def to_module_atom(string) do
    String.to_atom("Elixir." <> string)
  end
end

