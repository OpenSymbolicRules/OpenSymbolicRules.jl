using TestItemRunner

@testitem "Contextual Assumptions" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x
    @syms Abs(a)
    
    # We create a dummy rule: Abs(~x) => ~x where is_positive(~x)
    r1 = @rule Abs(~x) => ~x where is_positive(~x)
    
    # Simplify without assumptions
    expr = Abs(x)
    res1 = simplify(expr, [r1])
    @test isequal(res1, Abs(x)) # no assumption, cannot simplify
    
    # Simplify with assumption
    res2 = simplify(expr, [r1]; assumptions=[GreaterThan(x, 0)])
    @test isequal(res2, x)
end
