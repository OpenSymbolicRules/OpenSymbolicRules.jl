using TestItemRunner
@testitem "Macro @load_osr" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    # Define our custom predicates and operators
    is_integer(x) = x isa Integer
    @syms x y Pow(a,b) Mul(a,b) Add(a,b) Power(a,b)

    rules = @load_osr("data/1.1-basic-exponents.json")
    
    @test length(rules) == 4
    
    # Test Identity Rule (id:3) -> Pow(z, 1) => z
    # Actually wait, the rule says `Pow(~z, 1) => ~z`? Let's check rule 3.
    # We will just evaluate it.
    @syms z
    expr = Pow(z, 1)
    res = rules[3](expr)
    @test isequal(res, z)

    nonzero_rules = @load_osr("data/1.2-nonzero-power.json")
    @test isequal(nonzero_rules[1](Power(2, 0)), 1)
    @test nonzero_rules[1](Power(x, 0)) === nothing
end
