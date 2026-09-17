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
