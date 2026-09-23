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

@testitem "Equation solving delegates to exact polynomial roots" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    result = solve(x^2 - 3x + 2 ~ 0, x)
    @test result isa PolynomialRootsResult
    @test result.roots == [(root=1 // 1, multiplicity=1), (root=2 // 1, multiplicity=1)]
    @test result.complete
end

@testitem "Simp and Dist are the identities RUBI's algebra gives them" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms a c f x

    # RUBI writes `Simp[u, x]` for "u, tidied up". Tidying is optional, so
    # returning `u` is a sound reading of it: the expression is unchanged and
    # the rewrite that produced it stays valid. What it is not is a head this
    # package leaves inert, which stops the rewrite chain dead — two thirds of
    # the problems that stalled in section 1.1.1 stalled on `Simp` or
    # `ExpandIntegrand`.
    @test isequal(Simp(Multiply(a, x), x), Multiply(a, x))
    @test isequal(Simp(a, x), a)

    # The corpus writes `Simp[u]` 200 times and `Simp[u, x]` 518 times. A
    # method for only the second turns the first into a MethodError the moment
    # the rule fires, which is what happened: two rules of section 1.3.4 alone
    # raised on 2246 problems.
    @test isequal(Simp(Multiply(a, x)), Multiply(a, x))
    @test isequal(Simp(a), a)

    # `Dist[u, v, x]` distributes `u` over `v`, and means `u*v` whatever it
    # distributes over, so the product is exact rather than approximate.
    @test isequal(Dist(c, Integral(f, x), x), Multiply(c, Integral(f, x)))
    @test isequal(Dist(c, a, x), Multiply(c, a))

    # `ExpandIntegrand` is deliberately absent: reading it as the identity is
    # mathematically sound but turns `Int(ExpandIntegrand(u, x), x)` back into
    # the integral it came from, which does not terminate.
    @test !isdefined(OpenSymbolicRules, :ExpandIntegrand)
end

@testitem "Subst performs capture-avoiding RUBI substitution" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y

    # OSR's `Subst[expression, variable, value]` has a specified, semantic
    # meaning.  It must not remain an inert utility head after an integration
    # rule introduces it: the subsequent rule needs to see the substituted
    # expression.
    @test isequal(Subst(Add(x, Power(x, 2)), x, y),
                  Add(y, Power(y, 2)))

    # Delegating to the binder-aware primitive preserves a free `y` from the
    # substitution rather than accidentally capturing it under the lambda.
    substituted = Subst(Lambda(y, Add(x, y)), x, y)
    @test alpha_equivalent(substituted, Lambda(:fresh, Add(y, :fresh)))
    @test :y in free_variables(substituted)
end
