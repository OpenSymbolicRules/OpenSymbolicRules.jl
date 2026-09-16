using TestItemRunner

@testitem "Assumptions Context" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x
    
    # We define a rule using `is_positive`
    # Let's say we simplify abs(x) -> x if x > 0
    @syms Abs(a)
    rules = [
        @rule Abs(~x) => ~x where is_positive(~x)
    ]
    
    # Without assumptions, it should do nothing
    expr = Abs(x)
    @test isequal(simplify(expr, rules), Abs(x))
    
    # With IsPositive(x)
    @test string(simplify(expr, rules, assumptions=[IsPositive(x)])) == string(x)
    
    # With GreaterThan(x, 0)
    @test string(simplify(expr, rules, assumptions=[GreaterThan(x, 0)])) == string(x)
    
    # Native number
    @test string(simplify(Abs(5), rules)) == "5"
    
    # Negative literal shouldn't match (abs(-5) would need a different rule, but for now just doesn't match)
    @test string(simplify(Abs(-5), rules)) == string(Abs(-5))
end
