using TestItemRunner

@testitem "Structured SAT operation results" begin
    using OpenSymbolicRules

    sat = solve(SATProblem([[1, 2], [-1, 2]]))
    @test sat isa SatResult
    @test sat.backend === BuiltinBackend()
    @test sat.model[2]

    unsat = solve(SATProblem([[1], [-1]]))
    @test unsat isa UnsatResult
    @test unsat.backend === BuiltinBackend()
end
