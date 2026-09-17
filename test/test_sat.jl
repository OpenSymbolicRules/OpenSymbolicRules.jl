using TestItemRunner

@testitem "Pure Julia SAT solves CNF clauses" begin
    using OpenSymbolicRules

    # (a ∨ b) ∧ (¬a ∨ b) ∧ (a ∨ ¬b) has the unique model a = b = true.
    @test satisfiable([[1, 2], [-1, 2], [1, -2]])
    @test !satisfiable([[1], [-1]])
    @test !satisfiable([Int[]])
end

@testitem "SAT input uses nonzero DIMACS literals" begin
    using OpenSymbolicRules

    @test_throws ArgumentError satisfiable([[0]])
    @test_throws ArgumentError satisfiable([[1, -1, 0]])
end
