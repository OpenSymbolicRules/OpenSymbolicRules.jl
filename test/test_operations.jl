using TestItemRunner

@testitem "Structured SAT operation results" begin
    using CommonSolve
    using OpenSymbolicRules

    @test OpenSymbolicRules.solve === CommonSolve.solve
    sat = solve(SATProblem([[1, 2], [-1, 2]]))
    @test sat isa SatResult
    @test sat.backend === BuiltinBackend()
    @test sat.model[2]

    unsat = solve(SATProblem([[1], [-1]]))
    @test unsat isa UnsatResult
    @test unsat.backend === BuiltinBackend()

    state = CommonSolve.init(SATProblem([[1]]), BuiltinBackend())
    @test CommonSolve.solve!(state) isa SatResult
end
