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

@testitem "A polynomial predicate distributes over a collection" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: LinearQ, QuadraticQ, PolyQ, PolynomialQ
    using SymbolicUtils

    @syms a b c d x

    linear = Add(a, Multiply(b, x))
    other_linear = Add(c, Multiply(d, x))
    quadratic = Add(a, Multiply(b, Power(x, 2)))

    # RUBI writes `LinearQ[{u, v}, x]` to ask about every element at once, the
    # same spelling `FreeQ[{a, b}, x]` uses. Reading the list as a single
    # expression makes the guard fail on a rule that plainly applies.
    @test LinearQ(linear, x)
    @test LinearQ(other_linear, x)
    # `["List", u, v]` compiles to a Julia vector, which is the shape a guard
    # actually receives.
    @test LinearQ([linear, other_linear], x)

    # One element that is not linear is enough to decline.
    @test !LinearQ([linear, quadratic], x)
    @test !LinearQ([linear, c], x)

    @test QuadraticQ([quadratic, quadratic], x)
    @test !QuadraticQ([quadratic, linear], x)

    @test PolynomialQ([linear, quadratic], x)
    @test PolyQ([linear, quadratic], x)
    @test PolyQ([linear, other_linear], x, 1)

    # An empty collection asks nothing, so nothing stands in the way.
    @test LinearQ(Any[], x)
end

@testitem "LinearMatchQ recognises an already-matched linear form" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: LinearMatchQ, LinearQ
    using SymbolicUtils

    @syms a b c d x

    # RUBI distinguishes being linear from being *written* linearly.
    # `LinearQ` asks about the degree; `LinearMatchQ` asks whether the
    # expression already has the shape `a. + b.*x` that the rules downstream
    # pattern-match against. The pair drives the normalization rules, which fire
    # exactly when something is linear but not yet in that shape.
    @test LinearMatchQ(x, x)
    @test LinearMatchQ(Multiply(b, x), x)
    @test LinearMatchQ(Multiply(x, b), x)
    @test LinearMatchQ(Add(a, x), x)
    @test LinearMatchQ(Add(a, Multiply(b, x)), x)
    @test LinearMatchQ(Add(Multiply(b, x), a), x)

    # Linear in degree, but not in the matched shape.
    @test LinearQ(Multiply(2, Add(a, Multiply(b, x))), x)
    @test !LinearMatchQ(Multiply(2, Add(a, Multiply(b, x))), x)

    # A coefficient that is not free of the variable is not a coefficient.
    @test !LinearMatchQ(Multiply(x, x), x)
    @test !LinearMatchQ(Add(a, Multiply(x, x)), x)

    # Degree zero and degree two are not linear in either sense.
    @test !LinearMatchQ(c, x)
    @test !LinearMatchQ(Power(x, 2), x)
    @test !LinearMatchQ(Add(a, Multiply(b, Power(x, 2))), x)

    # RUBI writes `LinearMatchQ[{u, v}, x]` for every element at once.
    @test LinearMatchQ([Add(a, Multiply(b, x)), Add(c, Multiply(d, x))], x)
    @test !LinearMatchQ([Add(a, Multiply(b, x)), Power(x, 2)], x)
    @test LinearMatchQ(Any[], x)
end

@testitem "BinomialQ recognises a two-term power form" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: BinomialQ, BinomialMatchQ
    using SymbolicUtils

    @syms a b c n x

    # RUBI calls `a + b*x^n` a binomial, with `a` and `b` and the exponent all
    # free of the variable. The degenerate forms count: `x^n` alone is one with
    # `a = 0` and `b = 1`.
    @test BinomialQ(Add(a, Multiply(b, Power(x, 3))), x)
    @test BinomialQ(Add(Multiply(b, Power(x, 3)), a), x)
    @test BinomialQ(Multiply(b, Power(x, n)), x)
    @test BinomialQ(Power(x, 3), x)
    @test BinomialQ(x, x)
    @test BinomialQ(Add(a, x), x)

    # A coefficient may itself be a product of things free of the variable.
    @test BinomialQ(Multiply(2, Multiply(c, Power(x, 3))), x)

    # Three terms, or a coefficient that mentions the variable, is not one.
    @test !BinomialQ(Add(a, Add(Multiply(b, x), Multiply(c, Power(x, 2)))), x)
    @test !BinomialQ(Multiply(x, Power(x, 3)), x)
    @test !BinomialQ(c, x)

    # With a degree, the exponent must be that one.
    @test BinomialQ(Add(a, Multiply(b, Power(x, 3))), x, 3)
    @test !BinomialQ(Add(a, Multiply(b, Power(x, 3))), x, 2)

    # A collection is read element by element.
    @test BinomialQ([Power(x, 2), Add(a, Multiply(b, Power(x, 2)))], x)
    @test !BinomialQ([Power(x, 2), c], x)

    # `BinomialMatchQ` asks the same question of the written shape.
    @test BinomialMatchQ(Add(a, Multiply(b, Power(x, 3))), x)
    @test !BinomialMatchQ(c, x)
    @test BinomialMatchQ([Power(x, 2), x], x)
end
