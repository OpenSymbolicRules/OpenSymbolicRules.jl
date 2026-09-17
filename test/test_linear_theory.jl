using TestItemRunner

@testitem "Exact rational linear constraints are decided" begin
    using OpenSymbolicRules

    x_at_least_one = LinearConstraint(Dict(:x => -1), :le, -1)
    x_at_most_two = LinearConstraint(Dict(:x => 1), :le, 2)
    @test linear_satisfiable([x_at_least_one, x_at_most_two])

    x_less_than_one = LinearConstraint(Dict(:x => 1), :lt, 1)
    @test !linear_satisfiable([x_at_least_one, x_less_than_one])

    x_at_least_one = LinearConstraint(Dict(:x => -1), :le, -1)
    y_at_least_one = LinearConstraint(Dict(:y => -1), :le, -1)
    sum_at_most_one = LinearConstraint(Dict(:x => 1, :y => 1), :le, 1)
    @test !linear_satisfiable([x_at_least_one, y_at_least_one, sum_at_most_one])
end

@testitem "Linear equality and strictness retain exact semantics" begin
    using OpenSymbolicRules

    x_equals_one = LinearConstraint(Dict(:x => 1), :eq, 1)
    x_less_than_one = LinearConstraint(Dict(:x => 1), :lt, 1)
    @test !linear_satisfiable([x_equals_one, x_less_than_one])
    @test linear_satisfiable([x_equals_one])
    @test_throws ArgumentError LinearConstraint(Dict(:x => 1), :ge, 1)
end

@testitem "DPLL(T) combines SAT clauses with linear constraints" begin
    using OpenSymbolicRules

    atoms = Dict(
        1 => LinearConstraint(Dict(:x => 1), :le, 0),
        2 => LinearConstraint(Dict(:x => -1), :lt, -1),
    )

    # x ≤ 0 ∨ x > 1 is satisfiable.
    @test linear_smt_satisfiable([[1, 2]], atoms)
    # Requiring both sides is contradictory.
    @test !linear_smt_satisfiable([[1], [2]], atoms)
    # Negating x ≤ 0 means x > 0, which is represented exactly.
    @test linear_smt_satisfiable([[-1], [2]], atoms)
end

@testitem "DPLL(T) encodes negated equalities as exact branches" begin
    using OpenSymbolicRules

    atoms = Dict(
        1 => LinearConstraint(Dict(:x => 1), :eq, 0),
        2 => LinearConstraint(Dict(:x => 1), :le, 0),
        3 => LinearConstraint(Dict(:x => -1), :le, 0),
    )

    # x ≠ 0 and x ≤ 0 is satisfiable (x < 0).
    @test linear_smt_satisfiable([[-1], [2]], atoms)
    # x ≠ 0, x ≤ 0, and x ≥ 0 is contradictory.
    @test !linear_smt_satisfiable([[-1], [2], [3]], atoms)
end
