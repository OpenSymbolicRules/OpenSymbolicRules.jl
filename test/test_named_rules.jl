using TestItemRunner

@testitem "Named OSR rules and observation" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @test isdefined(OpenSymbolicRules, :simplify)
    @test !isdefined(OpenSymbolicRules, :osr_simplify)

    @syms x Pow(a, b) Mul(a, b) Add(a, b)
    rules = @load_osr("data/1.1-basic-exponents.json")

    @test rules[3] isa OSRRule
    @test rules[3].name == "test:basic-exponents:3"
    @test rules[3].description == "Identity power: x^1 = x"
    @test rules[3].provenance["method"] == "authored"
    @test rules[3].provenance["sources"][1]["locator"] == "test:basic-exponents:3"
    @test_throws ArgumentError OpenSymbolicRules._compile_rule_exprs([Dict("pattern" => "x_", "result" => "x_")])
    duplicate_documents = [
        Dict("identity" => "test:one", "rules" => [Dict("id" => 1)]),
        Dict("identity" => "test:one", "rules" => [Dict("id" => 1)]),
    ]
    @test_throws ArgumentError OpenSymbolicRules._validate_rule_identities(duplicate_documents)
    missing_semantics = Dict(
        "section" => "1.1",
        "semantics" => Dict("Power" => "openmath:arith1#power"),
        "rules" => [Dict("id" => 1, "pattern" => ["Power", "x_", 1], "result" => ["Add", "x_", 1], "constraints" => Any[])],
    )
    @test_throws ArgumentError OpenSymbolicRules._validate_openmath_semantics([missing_semantics])

    result, steps = simplify(Pow(x, 1), rules; mode=:trace)
    @test isequal(result, x)
    @test length(steps) == 1
    @test steps[1].rule.name == "test:basic-exponents:3"

    observed = NamedTuple[]
    result = simplify(Pow(x, 1), rules; on_step=step -> push!(observed, step))
    @test isequal(result, x)
    @test length(observed) == 1
    @test observed[1].rule.name == "test:basic-exponents:3"

    @test_throws ArgumentError simplify(Pow(x, 1), rules; mode=:verbose)
end
