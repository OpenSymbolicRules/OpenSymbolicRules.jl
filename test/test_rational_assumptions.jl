using TestItemRunner

@testitem "Rational assumption consistency detects contradictory bounds" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x

    @test rational_assumptions_satisfiable([GreaterThan(x, 0), LessThan(x, 0)]) === false
    @test rational_assumptions_satisfiable([GreaterThan(x, 0), LessThan(x, 2)]) === true
    @test rational_assumptions_satisfiable([IsPositive(x), LessThan(x, 0)]) === false
end

@testitem "Rational assumption consistency remains conservative" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x

    @test rational_assumptions_satisfiable([IsNonzero(x)]) === nothing
    @test rational_assumptions_satisfiable([GreaterThan(x, sin(x))]) === nothing
end
