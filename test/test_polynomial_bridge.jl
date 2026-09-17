using TestItemRunner

@testitem "SymbolicUtils expressions convert to exact sparse polynomials" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    polynomial = to_sparse_polynomial(x^2 * y + 3 // 2, [:x, :y])

    @test polynomial == SparsePolynomial([:x, :y],
        Dict((2, 1) => 1, (0, 0) => 3 // 2))
    @test isequal(to_symbolic_polynomial(polynomial, Dict(:x => x, :y => y)),
                  x^2 * y + 3 // 2)
end

@testitem "The polynomial bridge rejects non-polynomial expressions" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    @test_throws ArgumentError to_sparse_polynomial(sin(x), [:x])
    @test_throws ArgumentError to_sparse_polynomial(x^-1, [:x])
    @test_throws ArgumentError to_sparse_polynomial(x + y, [:x])
end
