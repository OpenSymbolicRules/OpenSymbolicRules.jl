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
