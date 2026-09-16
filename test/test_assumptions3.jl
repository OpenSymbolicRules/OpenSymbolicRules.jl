using TestItemRunner

@testitem "Contextual Assumptions API" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x
    @syms Abs(a)
    
    r1 = @rule Abs(~x) => ~x where is_positive(~x)
    rules = [r1]
    expr = Abs(x)
    
    res1 = simplify(expr, rules)
    @test isequal(res1, expr)
    
    res2 = assuming(GreaterThan(x, 0)) do
        simplify(expr, rules)
    end
    @test isequal(res2, x)
end
