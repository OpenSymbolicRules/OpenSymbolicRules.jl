using TestItemRunner

@testitem "OSR manifests, profiles, and binders" begin
    using OpenSymbolicRules
    using SymbolicUtils

    root = joinpath(@__DIR__, "data", "profiles")

    @test rule_paths(root) == [joinpath(root, "rules", "default.json")]
    @test rule_paths(root; profile=:to_cnf) == [joinpath(root, "rules", "cnf.json")]
    @test_throws ArgumentError rule_paths(root; profile=:missing)

    inferences = load_inference_profile(root, :resolution)
    @test length(inferences) == 1
    @test inferences[1].id == 1
    @test inferences[1].conclusion == "False"
    @test_throws ArgumentError load_inference_profile(root, :missing)

    @syms x y z Pow(a, b) Power(a, b)
    default_rules = @load_osr_profile("data/profiles")
    cnf_rules = @load_osr_profile("data/profiles", :to_cnf)
    @test isequal(default_rules[1](Power(x, 1)), x)
    @test cnf_rules[1](Pow(x, 0)) == 1

    module BareProfileLoader
        using OpenSymbolicRules
        const rules = @load_osr_profile("data/profiles")
    end
    @test isequal(BareProfileLoader.rules[1](Power(x, 1)), x)

    module BareLogicLoader
        using OpenSymbolicRules
        const rules = @load_osr("data/logic/1.1-boolean-identities.json")
    end
    @test isequal(BareLogicLoader.rules[1](And(x, true)), x)

    binder = OpenSymbolicRules.osr_to_expr(["Forall", ["x"], ["Not", "x"]])
    @test binder == :(Forall([:x], Not(x)))

    nary_add = OpenSymbolicRules.osr_to_expr(["Add", "x", "y", "z"])
    @test isequal(eval(nary_add), Add(Add(x, y), z))
end
