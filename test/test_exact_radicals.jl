using TestItemRunner

@testitem "Exact numeric square-root normalization" begin
    using OpenSymbolicRules

    @test normalize_sqrt(0) == 0
    @test normalize_sqrt(49) == 7
    @test isequal(normalize_sqrt(2), Sqrt(2))
    @test isequal(normalize_sqrt(12), 2 * Sqrt(3))
    @test isequal(normalize_sqrt(12 // 49), (2 // 7) * Sqrt(3))
    @test isequal(normalize_sqrt(7 // 2), (1 // 2) * Sqrt(14))
    @test isequal(normalize_sqrt(-1), Sqrt(-1))

    squareful = big(1_000_003)^2 * 3
    normalized = normalize_sqrt(squareful)
    @test isequal(normalized, Sqrt(squareful))
    @test normalize_sqrt(big(1_000_003)^2) == big(1_000_003)
end
