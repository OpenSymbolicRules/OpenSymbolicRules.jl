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

@testitem "Structured linear SMT operation results" begin
    using OpenSymbolicRules

    atoms = Dict(1 => LinearConstraint(Dict(:x => 1), :le, 0))
    result = solve(SMTProblem([[1]], atoms))
    @test result isa SatResult
    @test result.model.rationals[:x] <= 0
    @test solve(SMTProblem([[1], [-1]], atoms)) isa UnsatResult
end

@testitem "Structured mixed rational SMT operation results" begin
    using OpenSymbolicRules

    atoms = Dict{Int,Union{LinearConstraint,EqualityConstraint}}(
        1 => LinearConstraint(Dict(:x => 1), :le, 0),
        2 => EqualityConstraint(:x, :y, :eq),
    )
    result = solve(SMTProblem([[1], [2]], atoms))
    @test result isa SatResult
    @test result.model.rationals[:x] <= 0
    @test result.model.rationals[:x] == result.model.rationals[:y]

    @test solve(SMTProblem([[1], [-1]], atoms)) isa UnsatResult
end

@testitem "Structured univariate polynomial operation results" begin
    using OpenSymbolicRules

    polynomial = SparsePolynomial([:x], Dict((2,) => 1, (1,) => -3, (0,) => 2))
    result = solve(UnivariatePolynomialProblem(polynomial))
    @test result isa PolynomialRootsResult
    @test result.roots == [(root=1 // 1, multiplicity=1), (root=2 // 1, multiplicity=1)]
    @test result.complete
    @test result.residual == SparsePolynomial([:x], Dict((0,) => 1))

    incomplete = solve(UnivariatePolynomialProblem(
        SparsePolynomial([:x], Dict((2,) => 1, (0,) => -2))))
    @test isempty(incomplete.roots)
    @test !incomplete.complete
end
