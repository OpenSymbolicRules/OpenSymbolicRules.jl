using TestItemRunner

const _SIBLING_PROFILE_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
if isfile(joinpath(_SIBLING_PROFILE_ROOT, "Calculus", "rules", "meta.json"))

@testitem "Current Calculus profile loads with canonical identities" begin
    using OpenSymbolicRules

    rules = @load_osr_profile("../../Calculus")

    @test length(rules) == 32
    @test rules[1].name == "calculus:1-limits/1.1-basic-limits:1"
    @test rules[1].provenance["method"] == "authored"
end

@testitem "Current Algebra and Logic profiles load" begin
    using OpenSymbolicRules

    algebra_rules = @load_osr_profile("../../Algebra")
    logic_rules = @load_osr_profile("../../Logic")

    @test length(algebra_rules) == 16
    @test algebra_rules[1].name == "algebra:1-powers/1.1-basic-exponents:1"
    @test length(logic_rules) == 35
    @test logic_rules[1].name == "logic:1-identities/1.1-boolean-identities:1"
end

@testitem "Current named algebra and trigonometry profiles load" begin
    using OpenSymbolicRules

    factor_rules = @load_osr_profile("../../Algebra", :factor_polynomials)
    trigonometry_rules = @load_osr_profile("../../Trigonometry", :sum_to_product)

    @test length(factor_rules) == 10
    @test factor_rules[1].name == "algebra:3-polynomials/3.2-common-factor:1"
    @test length(trigonometry_rules) == 11
    @test trigonometry_rules[1].name == "trigonometry:1-basic-identities/1.1-pythagorean:1"
end

end # Sibling repositories are available only in an ecosystem checkout.
