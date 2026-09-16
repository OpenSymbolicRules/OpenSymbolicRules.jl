using TestItemRunner

@testitem "Core Package Rules (Algebra + Calculus)" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x y c
    @syms Add(a,b) Mul(a,b) Div(a,b) Pow(a,b) Derivative(a,b)
    @syms Sin(a) Cos(a) Exp(a) Log(a)
    
    # Load the actual rules shipped with the package
    rules = @load_osr_profile("../data/rules")
    
    # Algebra test
    expr1 = Mul(1, Sin(x))
    res1 = simplify(expr1, rules)
    @test string(res1) == "Sin(x)"
    
    expr2 = Add(x, Mul(-1, x))
    res2 = simplify(expr2, rules)
    @test string(res2) == "0"
    
    # Derivative test with algebra simplification
    # d/dx (x * sin(x))
    expr3 = Derivative(Mul(x, Sin(x)), x)
    res3 = simplify(expr3, rules)
    
    # Raw derivative is Add(Mul(1, Sin(x)), Mul(x, Mul(Cos(x), 1)))
    # With algebra rules, it simplifies to Add(Sin(x), Mul(x, Cos(x)))
    s = string(res3)
    @test occursin("Sin", s)
    @test occursin("Cos", s)
    
    # Because Metatheory.jl uses e-graphs, the output might be structurally identical but different
    # Check if we at least eliminated the `1` multipliers
    @test !occursin("Mul(1,", s)
    @test !occursin(", 1)", s)
end

@testitem "Core Package Rules (Integration)" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x c
    @syms Add(a,b) Mul(a,b) Div(a,b) Pow(a,b) Integral(a,b)
    @syms Sin(a) Cos(a) Exp(a) Log(a)
    
    rules = @load_osr_profile("../data/rules")
    
    # Integral of constant: I(c, x) => c * x
    expr1 = Integral(c, x)
    res1 = simplify(expr1, rules)
    @test string(res1) == "Mul(c, x)" || string(res1) == "Mul(x, c)"
    
    # Linearity and constant multiple: I(3 * x^2 + Sin(x), x)
    expr2 = Integral(Add(Mul(3, Pow(x, 2)), Sin(x)), x)
    res2 = simplify(expr2, rules)
    
    s2 = string(res2)
    # The integration should distribute and integrate terms
    # I(3x^2) => 3 * (x^3 / 3)
    # I(Sin(x)) => -1 * Cos(x)
    @test occursin("Pow(x, 3)", s2) || occursin("Pow(x, Add(2, 1))", s2)
    @test occursin("Cos(x)", s2)
end
