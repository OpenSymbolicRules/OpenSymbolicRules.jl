using TestItemRunner

@testitem "differentiate builds the canonical lambda and applies the Calculus rules" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x c

    rules = @load_osr("data/calculus/3.1-canonical-lambda.json")

    # The roadmap asks for an expression-first constructor that normalizes
    # immediately to the one canonical representation. `Derivative` binds its
    # variable in a `Lambda`, as the OpenMath `fns1#lambda` symbol prescribes,
    # so the constructor's whole job is to build that form, rewrite it, and
    # hand back the body — never a second expression tree.
    @test isequal(differentiate(Power(x, 3), x, rules),
                  Multiply(3, Power(x, Add(3, -1))))
    @test isequal(differentiate(Sin(x), x, rules), Cos(x))
    @test OpenSymbolicRules.osr_number(differentiate(x, x, rules)) == 1

    # A constant differentiates to zero, whatever it is made of.
    @test OpenSymbolicRules.osr_number(differentiate(c, x, rules)) == 0

    # The structural rules compose: a sum differentiates term by term.
    @test isequal(differentiate(Add(Sin(x), Cos(x)), x, rules),
                  Add(Cos(x), Multiply(-1, Sin(x))))
end

@testitem "differentiate leaves what it cannot evaluate visible" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Weird(a)

    rules = @load_osr("data/calculus/3.1-canonical-lambda.json")

    # No rule covers this head, so the derivative stays a `Derivative` term:
    # an operation this rule set cannot carry out is an unevaluated expression,
    # never a closed form it did not reach.
    unevaluated = differentiate(Weird(x), x, rules)
    @test occursin("Derivative", string(unevaluated))
    @test !evaluated_derivative(unevaluated)

    # A derivative it did carry out reports as evaluated.
    @test evaluated_derivative(differentiate(Sin(x), x, rules))
end

@testitem "limit builds the canonical binder and applies the Calculus rules" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x c

    rules = @load_osr("data/calculus/3.1-canonical-lambda.json")

    # `Limit` carries its point, its approach, and a lambda-bound expression.
    # The constructor takes them in the order a reader expects and assembles
    # that form.
    @test isequal(limit(c, x, 0, rules), c)
    @test OpenSymbolicRules.osr_number(limit(Divide(Sin(x), x), x, 0, rules)) == 1
    @test OpenSymbolicRules.osr_number(limit(Divide(Tan(x), x), x, 0, rules)) == 1

    # An uncovered limit stays a `Limit` term rather than claiming a value.
    @test occursin("Limit", string(limit(Divide(Sin(x), Cos(x)), x, 1, rules)))
end
