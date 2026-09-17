using TestItemRunner

@testitem "Ground equality constraints propagate equivalence classes" begin
    using OpenSymbolicRules

    @test equality_satisfiable([
        EqualityConstraint(:a, :b, :eq),
        EqualityConstraint(:b, :c, :eq),
        EqualityConstraint(:a, :c, :eq),
    ])
    @test !equality_satisfiable([
        EqualityConstraint(:a, :b, :eq),
        EqualityConstraint(:b, :c, :eq),
        EqualityConstraint(:a, :c, :ne),
    ])
end

@testitem "DPLL(T) combines equality atoms with Boolean clauses" begin
    using OpenSymbolicRules

    atoms = Dict(
        1 => EqualityConstraint(:a, :b, :eq),
        2 => EqualityConstraint(:a, :b, :ne),
    )

    @test smt_satisfiable([[1, 2]], atoms)
    @test !smt_satisfiable([[1], [2]], atoms)
    @test smt_satisfiable([[-1], [2]], atoms)
end

@testitem "Equality theory returns checkable equivalence classes" begin
    using OpenSymbolicRules

    constraints = [
        EqualityConstraint(:a, :b, :eq),
        EqualityConstraint(:c, :d, :eq),
        EqualityConstraint(:a, :c, :ne),
    ]
    classes = equality_model(constraints)

    @test classes !== nothing
    @test classes[:a] == classes[:b]
    @test classes[:c] == classes[:d]
    @test classes[:a] != classes[:c]
end

@testitem "Equality DPLL(T) returns a Boolean and equality model" begin
    using OpenSymbolicRules

    atoms = Dict(
        1 => EqualityConstraint(:a, :b, :eq),
        2 => EqualityConstraint(:a, :b, :ne),
    )
    model = smt_model([[1, 2]], atoms)

    @test model !== nothing
    @test any(literal -> model.booleans[abs(literal)] == (literal > 0), [1, 2])
    @test (model.booleans[1] && model.classes[:a] == model.classes[:b]) ||
          (model.booleans[2] && model.classes[:a] != model.classes[:b])
    @test smt_model([[1], [2]], atoms) === nothing
end
