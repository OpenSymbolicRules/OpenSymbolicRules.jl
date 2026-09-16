using TestItemRunner

@testitem "Named OSR rules and observation" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @test isdefined(OpenSymbolicRules, :simplify)
    @test !isdefined(OpenSymbolicRules, :osr_simplify)

    @syms x Pow(a, b) Mul(a, b) Add(a, b)
    rules = @load_osr("data/1.1-basic-exponents.json")

    @test rules[3] isa OSRRule
    @test rules[3].name == "1.1:3"
    @test rules[3].description == "Identity power: x^1 = x"
    @test_throws ArgumentError OpenSymbolicRules._compile_rule_exprs([Dict("pattern" => "x_", "result" => "x_")])
    duplicate_documents = [
        Dict("section" => "1.1", "rules" => [Dict("id" => 1)]),
        Dict("section" => "1.1", "rules" => [Dict("id" => 1)]),
    ]
    @test_throws ArgumentError OpenSymbolicRules._validate_rule_identities(duplicate_documents)

    result, steps = simplify(Pow(x, 1), rules; mode=:trace)
    @test isequal(result, x)
    @test length(steps) == 1
    @test steps[1].rule.name == "1.1:3"

    observed = NamedTuple[]
    result = simplify(Pow(x, 1), rules; on_step=step -> push!(observed, step))
    @test isequal(result, x)
    @test length(observed) == 1
    @test observed[1].rule.name == "1.1:3"

    @test_throws ArgumentError simplify(Pow(x, 1), rules; mode=:verbose)
end
