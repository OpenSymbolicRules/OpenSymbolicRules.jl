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

    @syms x Pow(a, b)
    default_rules = @load_osr_profile("data/profiles")
    cnf_rules = @load_osr_profile("data/profiles", :to_cnf)
    @test isequal(default_rules[1](Pow(x, 1)), x)
    @test cnf_rules[1](Pow(x, 0)) == 1

    binder = OpenSymbolicRules.osr_to_expr(["Forall", ["x"], ["Not", "x"]])
    @test binder == :(Forall([:x], Not(x)))
end
