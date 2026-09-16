using TestItemRunner

@testitem "Basic Test" begin
    using OpenSymbolicRules
    @test 1 == 1
end
