using TestItemRunner

@testitem "Exact sparse polynomial reduction" begin
    using OpenSymbolicRules

    p = SparsePolynomial([:x, :y], Dict((2, 0) => 1, (0, 1) => 1))
    q = SparsePolynomial([:x, :y], Dict((1, 1) => 1, (0, 0) => -1))

    @test OpenSymbolicRules.leading_monomial(p, :lex) == (2, 0)
    @test OpenSymbolicRules.leading_monomial(q, :grevlex) == (1, 1)
    @test OpenSymbolicRules.spoly(p, q; ordering=:lex) ==
        SparsePolynomial([:x, :y], Dict((0, 2) => 1, (1, 0) => 1))

    divisor = SparsePolynomial([:x], Dict((1,) => 1, (0,) => -1))
    dividend = SparsePolynomial([:x], Dict((2,) => 1, (0,) => -1))
    @test normal_form(dividend, [divisor]; ordering=:lex) ==
        SparsePolynomial([:x], Dict((0,) => 0))
end

@testitem "Buchberger bases prove ideal membership" begin
    using OpenSymbolicRules

    xy_minus_one = SparsePolynomial([:x, :y], Dict((1, 1) => 1, (0, 0) => -1))
    y_squared_minus_one = SparsePolynomial([:x, :y], Dict((0, 2) => 1, (0, 0) => -1))
    x_squared_minus_one = SparsePolynomial([:x, :y], Dict((2, 0) => 1, (0, 0) => -1))

    basis = groebner_basis([xy_minus_one, y_squared_minus_one]; ordering=:lex)

    @test all(normal_form(OpenSymbolicRules.spoly(left, right; ordering=:lex), basis; ordering=:lex) ==
              SparsePolynomial([:x, :y], Dict())
              for (index, left) in enumerate(basis) for right in basis[index + 1:end])
    @test ideal_membership(x_squared_minus_one, basis; ordering=:lex)
end

@testitem "Exact univariate resultants" begin
    using OpenSymbolicRules

    polynomial = SparsePolynomial([:x], Dict((2,) => 1, (0,) => -1))
    shared_root = SparsePolynomial([:x], Dict((1,) => 1, (0,) => -1))
    disjoint = SparsePolynomial([:x], Dict((1,) => 1, (0,) => -2))

    @test resultant(polynomial, shared_root) == 0
    @test resultant(polynomial, disjoint) == 3
end

@testitem "Exact univariate discriminants" begin
    using OpenSymbolicRules

    quadratic = SparsePolynomial([:x], Dict((2,) => 1, (0,) => -1))
    repeated_root = SparsePolynomial([:x], Dict((2,) => 1, (1,) => -2, (0,) => 1))
    cubic = SparsePolynomial([:x], Dict((3,) => 1, (1,) => -1))

    @test discriminant(quadratic) == 4
    @test discriminant(repeated_root) == 0
    @test discriminant(cubic) == 4
    @test discriminant(SparsePolynomial([:x], Dict((1,) => 3, (0,) => 2))) == 1
    @test_throws ArgumentError discriminant(SparsePolynomial([:x], Dict()))
    @test_throws ArgumentError discriminant(SparsePolynomial([:x, :y], Dict((1, 0) => 1)))
end

@testitem "Exact univariate square-free decomposition" begin
    using OpenSymbolicRules

    polynomial = SparsePolynomial([:x], Dict(
        (5,) => 1, (4,) => 4, (3,) => 1, (2,) => -10, (1,) => -4, (0,) => 8,
    )) # (x - 1)^2 * (x + 2)^3
    decomposition = squarefree_decomposition(polynomial)

    @test decomposition == [
        (factor=SparsePolynomial([:x], Dict((1,) => 1, (0,) => -1)), multiplicity=2),
        (factor=SparsePolynomial([:x], Dict((1,) => 1, (0,) => 2)), multiplicity=3),
    ]
    @test squarefree_decomposition(SparsePolynomial([:x], Dict((1,) => 1, (0,) => -1))) == [
        (factor=SparsePolynomial([:x], Dict((1,) => 1, (0,) => -1)), multiplicity=1),
    ]
    @test_throws ArgumentError squarefree_decomposition(SparsePolynomial([:x], Dict()))
end
