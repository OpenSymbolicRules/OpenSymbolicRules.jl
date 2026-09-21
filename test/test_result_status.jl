using TestItemRunner

@testitem "An operation reports what kind of result it reached" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: OperationResult, status, value, assumptions
    using SymbolicUtils

    @syms x c
    @syms Opaque(a)

    rules = @load_osr("data/calculus/3.1-canonical-lambda.json")

    # The roadmap asks that an unknown result never be rendered as a proved
    # equality. The expression alone cannot say which it is, so the operation
    # says so: `mode = :status` returns the reading beside the value, the way
    # `simplify(...; mode = :trace)` returns the steps beside it.
    proved = differentiate(Sin(x), x, rules; mode=:status)
    @test proved isa OperationResult
    @test status(proved) === :proved
    @test isequal(value(proved), Cos(x))
    @test isempty(assumptions(proved))

    # A derivative no rule covers is an unevaluated operation, not a closed
    # form: the value is the `Derivative` term that is still standing.
    unevaluated = differentiate(Opaque(x), x, rules; mode=:status)
    @test status(unevaluated) === :unevaluated
    @test occursin("Derivative", string(value(unevaluated)))

    # And it says so when printed, so nothing reads as proved that is not.
    @test occursin("unevaluated", lowercase(sprint(show, unevaluated)))
    @test occursin("proved", lowercase(sprint(show, proved)))

    # The default shape is unchanged: the expression, for the ergonomic path.
    @test isequal(differentiate(Sin(x), x, rules), Cos(x))

    # A limit reports the same way.
    @test status(limit(c, x, 0, rules; mode=:status)) === :proved
    @test status(limit(Divide(Sin(x), Cos(x)), x, 1, rules; mode=:status)) === :unevaluated

    # An unknown mode is a programming error rather than a silent default.
    @test_throws ArgumentError differentiate(Sin(x), x, rules; mode=:whatever)
end

@testitem "A result carries the assumptions it was reached under" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: OperationResult, status, value, assumptions
    using SymbolicUtils

    @syms x

    rules = @load_osr("data/calculus/3.1-canonical-lambda.json")

    # A rewrite that fired under a hypothesis is conditional on it, and saying
    # so is the difference between a proved closed form and one that holds
    # where something was assumed.
    conditional = assuming(IsNonzero(x)) do
        differentiate(Sin(x), x, rules; mode=:status)
    end
    @test status(conditional) === :conditional
    @test !isempty(assumptions(conditional))
    @test occursin("conditional", lowercase(sprint(show, conditional)))

    # Without a hypothesis the same rewrite is simply proved.
    @test status(differentiate(Sin(x), x, rules; mode=:status)) === :proved
end
