using TestItemRunner

@testitem "Numeric SMT combines equality and rational linear atoms" begin
    using OpenSymbolicRules

    atoms = Dict{Int,Union{LinearConstraint,EqualityConstraint}}(
        1 => EqualityConstraint(:x, :y, :eq),
        2 => LinearConstraint(Dict(:x => 1), :le, 0),
        3 => LinearConstraint(Dict(:y => -1), :le, -1),
    )

    # x = y, x ≤ 0, y ≥ 1 is impossible over ℚ.
    @test !rational_smt_satisfiable([[1], [2], [3]], atoms)

    compatible = Dict{Int,Union{LinearConstraint,EqualityConstraint}}(
        1 => EqualityConstraint(:x, :y, :eq),
        2 => LinearConstraint(Dict(:x => 1), :le, 0),
        3 => LinearConstraint(Dict(:y => -1), :le, 0),
    )
    @test rational_smt_satisfiable([[1], [2], [3]], compatible)
end

@testitem "Numeric SMT preserves disequality atom meaning in models" begin
    using OpenSymbolicRules

    atoms = Dict{Int,Union{LinearConstraint,EqualityConstraint}}(
        1 => EqualityConstraint(:x, :y, :ne),
        2 => LinearConstraint(Dict(:x => 1), :eq, 0),
        3 => LinearConstraint(Dict(:y => 1), :eq, 1),
    )
    model = rational_smt_model([[1], [2], [3]], atoms)

    @test model !== nothing
    @test model.booleans[1]
    @test model.rationals[:x] != model.rationals[:y]
end
