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

@testitem "SAT produces a checkable Boolean model" begin
    using OpenSymbolicRules

    clauses = [[1, 2], [-1, 2], [1, -2]]
    model = sat_model(clauses)

    @test model !== nothing
    @test all(any(literal -> model[abs(literal)] == (literal > 0), clause)
              for clause in clauses)
    @test sat_model([[1], [-1]]) === nothing
end
