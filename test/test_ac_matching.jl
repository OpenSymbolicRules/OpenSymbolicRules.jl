using TestItemRunner

@testitem "Associative-commutative rule compilation" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    @syms Plus(a, b) Times(a, b) Log(a)

    rules = @load_osr("data/commutative/1.2-openmath-driven.json")

    # Commutativity is a property of the OpenMath symbol a head is bound to,
    # never of the head's spelling.  `Plus` is declared as `arith1#plus`, so it
    # matches in either operand order even though it is not named `Add`.
    @test rules[1].rule isa SymbolicUtils.ACRule
    @test isequal(simplify(Plus(x, 0), rules), x)
    @test isequal(simplify(Plus(0, x), rules), x)

    # `arith1#times` carries no shape information in OSR, so an operand may be a
    # matrix.  Reordering it would be unsound and must not happen.
    @test !(rules[2].rule isa SymbolicUtils.ACRule)
    @test isequal(simplify(Times(x, 1), rules), x)
    @test isequal(simplify(Times(1, x), rules), Times(1, x))
end

@testitem "Constrained rules stay guarded under AC matching" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    @syms Plus(a, b) Times(a, b) Log(a)

    rules = @load_osr("data/commutative/1.2-openmath-driven.json")
    product_rule = rules[3]

    # The logarithm product rule is only valid for positive arguments, so it
    # must stay inactive until both hypotheses are available.
    @test isequal(simplify(Plus(Log(x), Log(y)), rules), Plus(Log(x), Log(y)))

    @test assuming(IsPositive(x), IsPositive(y)) do
        isequal(simplify(Plus(Log(x), Log(y)), rules), Log(Times(x, y)))
    end

    # A one-sided hypothesis is not enough.
    @test assuming(IsPositive(x)) do
        isequal(simplify(Plus(Log(x), Log(y)), rules), Plus(Log(x), Log(y)))
    end

    @test product_rule.rule isa SymbolicUtils.ACRule
end

@testitem "AC matching replaces pattern duplication" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Add(a, b)

    # A single `ACRule` now covers both operand orders, so the compiler no
    # longer emits a mirrored copy of every commutative pattern.
    @test !isdefined(OpenSymbolicRules, :OSRAlternatives)

    rules = @load_osr("data/commutative/1.1-additive-identity.json")
    @test length(rules) == 1
    @test isequal(simplify(Add(0, x), rules), x)
    @test isequal(simplify(Add(x, 0), rules), x)
end
