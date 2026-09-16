using TestItemRunner

@testitem "Assumptions Context" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x
    
    @syms Abs(a)
    rules = [
        @rule Abs(~x) => ~x where is_positive(~x)
    ]
    
    expr = Abs(x)
    @test isequal(simplify(expr, rules), Abs(x))
    
    # Check with ~ (Equation) which we now support natively
    @test string(simplify(expr, rules, assumptions=[IsPositive(x)])) == string(x)
    
    @test string(simplify(expr, rules, assumptions=[GreaterThan(x, 0)])) == string(x)
    
    # We could also support equation assumptions if needed
    @test (x ~ 0) isa Equation
    
    @test string(simplify(Abs(5), rules)) == "5"
    @test string(simplify(Abs(-5), rules)) == string(Abs(-5))
end
