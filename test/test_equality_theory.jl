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
