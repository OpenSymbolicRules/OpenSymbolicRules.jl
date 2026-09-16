using TestItemRunner

@testitem "Calculus Step-by-step" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x n c Pow(a,b) Mul(a,b) Add(a,b) Derivative(a,b)
    
    # Load basic derivatives rules
    calc_rules = @load_osr("data/calculus/2.1-basic-derivatives.json")
    
    # Test Constant Rule: Derivative(c, x) => 0
    expr1 = Derivative(c, x)
    res1, steps1 = simplify(expr1, calc_rules, mode=:trace)
    @test string(res1) == "0"
    
    # Test Power Rule: Derivative(x^n, x) => n * x^(n-1)
    expr2 = Derivative(Pow(x, n), x)
    res2, steps2 = simplify(expr2, calc_rules, mode=:trace)
    @test string(res2) == "Mul(n, Pow(x, Add(-1, n)))" || string(res2) == "Mul(n, Pow(x, Add(n, -1)))"
end
