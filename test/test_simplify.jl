using TestItemRunner

@testitem "Simplifier" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x y Pow(a,b) Mul(a,b) Add(a,b) Sin(a) Cos(a)
    
    # Load algebra exponents rules
    alg_rules = @load_osr("data/1.1-basic-exponents.json")
    # Load trigonometry rules
    trig_rules = @load_osr("data/trig/1.1-pythagorean.json")
    
    all_rules = vcat(alg_rules, trig_rules)
    
    # Test Algebra: (x^2)^3 -> x^6
    expr1 = Pow(Pow(x, 2), 3)
    res1 = simplify(expr1, all_rules)
    @test isequal(res1, Pow(x, Mul(2, 3)))
    
    # Test Algebra: x^0 remains guarded when x is not known to be nonzero.
    expr2 = Pow(x, 0)
    res2 = simplify(expr2, all_rules)
    @test isequal(res2, expr2)
    
    # Test Trigonometry: sin^2(x) + cos^2(x) -> 1
    expr3 = Add(Pow(Sin(x), 2), Pow(Cos(x), 2))
    res3 = simplify(expr3, all_rules)
    @test string(res3) == "1"
    
    # Test Combined: (sin^2(x) + cos^2(x))^0 -> 1^0 -> 1
    expr4 = Pow(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 0)
    res4 = simplify(expr4, all_rules)
    @test string(res4) == "1"
end

@testitem "Step-by-step Simplifier" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x Pow(a,b) Mul(a,b) Add(a,b) Sin(a) Cos(a)
    
    alg_rules = @load_osr("data/1.1-basic-exponents.json")
    trig_rules = @load_osr("data/trig/1.1-pythagorean.json")
    all_rules = vcat(alg_rules, trig_rules)
    
    expr = Pow(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 0)
    res, steps = simplify(expr, all_rules, mode=:trace)
    
    @test string(res) == "1"
    @test length(steps) > 0
    
    # The first step should be Pythagoras: Sin^2 + Cos^2 -> 1
    @test string(steps[1].before) == "Add(Pow(Sin(x), 2), Pow(Cos(x), 2))"
    @test string(steps[1].after) == "1"
    
    # The second step should be Pow(1, 0) -> 1
    @test string(steps[2].before) == "Pow(1, 0)"
    @test string(steps[2].after) == "1"
end
