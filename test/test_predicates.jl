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

    # A symbolic inequality is not a proof.  Conditional rewrites must remain
    # inactive until their condition can be established.
    @test NotEqual(2, 0) == true
    @test NotEqual(0, 0) == false
    @test NotEqual(x, 0) == false

    # `NonzeroQ` is required by Algebra's x^0 rule.  It must be decidable for
    # literals and from a local mathematical hypothesis.
    @test is_nonzero(2) == true
    @test is_nonzero(0) == false
    @test is_nonzero(x) == false
    @test assuming(IsNonzero(x)) do
        is_nonzero(x)
    end
end

@testitem "is_symbol recognises a variable and nothing else" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: is_symbol
    using SymbolicUtils

    @syms x
    @syms F(a)

    # A rule that binds a variable of the problem — the variable of an integral,
    # a derivative, a sum, or a limit — is valid only when that operand really
    # is a variable.
    @test is_symbol(x)

    # A compound expression is not a variable, however simple.
    @test !is_symbol(F(x))
    @test !is_symbol(Multiply(2, x))
    # Nor is a literal.
    @test !is_symbol(2)
    @test !is_symbol(-3 // 4)
    @test !is_symbol(:x)
end

@testitem "A symbol-typed wildcard matches only a variable" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr
    using SymbolicUtils

    @test osr_to_expr("x_symbol") ==
          Expr(:call, :~, Expr(:(::), :x, GlobalRef(OpenSymbolicRules, :is_symbol)))

    @syms y
    rules = @load_osr("data/wildcards/1.8-symbol-domain.json")

    # The integrand is bound whatever it is; the integration variable is not.
    @test isequal(rules[1](Integral(Power(y, 3), y)), Power(y, 3))
    @test rules[1](Integral(Power(y, 3), 2)) === nothing
    @test rules[1](Integral(Power(y, 3), Multiply(2, y))) === nothing
end
