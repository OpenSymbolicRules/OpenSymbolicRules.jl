using TestItemRunner

@testitem "Current Calculus profile loads with canonical identities" begin
    using OpenSymbolicRules

    rules = @load_osr_profile("../../Calculus")

    @test length(rules) == 32
    @test rules[1].name == "calculus:1-limits/1.1-basic-limits:1"
    @test rules[1].provenance["method"] == "authored"
end
