using TestItemRunner

@testitem "Contextual Assumptions from JSON" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x
    @syms Abs(a)
    
    # We will just construct the JSON data structure directly since we can't easily mock a file right now
    data = Dict("section" => "test", "rules" => [
        Dict(
            "id" => 1,
            "pattern" => ["Abs", "~x"],
            "result" => "~x",
            "constraints" => [
                ["PositiveQ", "~x"]
            ]
        )
    ])
    
    # Let's compile it manually to get the rules
    rule_exprs = OpenSymbolicRules._compile_rule_exprs(data["rules"]; section=data["section"])
    
    # The rule expressions need to be evaluated in a module where Abs is defined
    # We evaluate them here in the test scope
    rules = [eval(expr) for expr in rule_exprs]
    
    expr = Abs(x)
    
    # Without assumptions
    res1 = simplify(expr, rules)
    @test isequal(res1, expr)
    
    # With assumptions
    res2 = simplify(expr, rules; assumptions=[GreaterThan(x, 0)])
    @test isequal(res2, x)
end
