using TestItemRunner

@testitem "Predicates" begin
    using OpenSymbolicRules
    using SymbolicUtils
    
    @syms x y a
    
    # Test FreeQ
    @test FreeQ(2 * y, x) == true
    @test FreeQ(2 * x, x) == false
    @test FreeQ(x, x) == false
    @test FreeQ(y, x) == true
    @test FreeQ(1, x) == true
    
    # Nested trees
    @test FreeQ(sin(x) + a, x) == false
    @test FreeQ(sin(y) + a, x) == true

    # Test basic types
    @test is_integer(2) == true
    @test is_integer(2.5) == false
    @test is_numeric(2.5) == true
    @test is_numeric(x) == false

    # `NonzeroQ` is required by Algebra's x^0 rule.  It must be decidable for
    # literals and from a local mathematical hypothesis.
    @test is_nonzero(2) == true
    @test is_nonzero(0) == false
    @test is_nonzero(x) == false
    @test assuming(IsNonzero(x)) do
        is_nonzero(x)
    end
end
