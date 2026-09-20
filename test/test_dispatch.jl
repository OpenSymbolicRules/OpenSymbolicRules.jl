using TestItemRunner

@testitem "Head-indexed dispatch preserves rule order" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: OSRDispatch, rule_head

    @syms x y
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    alg_rules = @load_osr("data/1.1-basic-exponents.json")
    trig_rules = @load_osr("data/trig/1.1-pythagorean.json")
    all_rules = vcat(alg_rules, trig_rules)

    dispatch = OSRDispatch(all_rules)
    @test dispatch isa OSRDispatch

    # Every rule of this fixture is headed by a concrete operation, so none of
    # them has to be tried against an unrelated head.
    @test all(rule -> rule_head(rule) !== nothing, all_rules)

    # Dispatching reproduces what a linear scan of every rule produces.
    for expr in (Pow(Pow(x, 2), 3), Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), Pow(x, 1),
                 Mul(x, y), Sin(x), x, 2)
        @test isequal(dispatch(expr), SymbolicUtils.Rewriters.Chain(all_rules)(expr))
    end
end

@testitem "Dispatch skips rules that cannot match" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: OSRDispatch, candidate_positions

    @syms x
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    alg_rules = @load_osr("data/1.1-basic-exponents.json")
    trig_rules = @load_osr("data/trig/1.1-pythagorean.json")
    all_rules = vcat(alg_rules, trig_rules)
    dispatch = OSRDispatch(all_rules)

    # `Sin` heads no rule in either fixture, so no matcher has to run at all.
    @test isempty(candidate_positions(dispatch, Sin(x)))
    @test isempty(candidate_positions(dispatch, x))
    @test isempty(candidate_positions(dispatch, 2))

    # Only the three `Pow` rules are candidates for a power.
    # Rule 1 is `Pow(Pow(~x, ~p), ~q)`: it requires a power under the power, so
    # it cannot match a power of a bare symbol however the exponent matches.
    @test candidate_positions(dispatch, Pow(x, 1)) == [3, 4]
    # Only the `Mul` rule is a candidate for a product.
    # Rule 2 is `Mul(Pow(~x, ~p), Pow(~x, ~q))`, and `Mul` is not commutative
    # here, so a product of bare symbols reaches no rule at all.
    @test isempty(candidate_positions(dispatch, Mul(x, x)))
    # `Add` heads the trigonometric identity, which is loaded last.
    @test candidate_positions(dispatch, Add(x, x)) == [5]

    @test isequal(dispatch(Pow(x, 1)), x)
end

@testitem "A rule that may match any head is always tried" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: OSRDispatch, rule_head

    @syms x
    @syms Pow(a, b)

    # A bare slot, a slot in head position, and an optional slot can all match a
    # term of any head, so none of them may be indexed away.  `SymbolicUtils`
    # allows an optional slot only under `+`, `*`, and `^`.
    @test rule_head(@rule ~a => 1) === nothing
    @test rule_head(@rule (~f)(~a) => 1) === nothing
    @test rule_head(@rule (~a)^(~!b) => 1) === nothing
    @test rule_head(@rule Pow(~a, ~b) => 1) !== nothing

    catch_all = @rule ~a => 0
    dispatch = OSRDispatch([catch_all])
    @test isequal(dispatch(Pow(x, 1)), 0)
    @test isequal(dispatch(x), 0)
end

@testitem "The simplifier is built on head-indexed dispatch" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    alg_rules = @load_osr("data/1.1-basic-exponents.json")
    trig_rules = @load_osr("data/trig/1.1-pythagorean.json")
    all_rules = vcat(alg_rules, trig_rules)

    expr = Pow(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 0)
    @test string(simplify(expr, all_rules)) == "1"

    # Tracing still reports every rewrite with its stable OSR name.
    result, steps = simplify(expr, all_rules; mode=:trace)
    @test string(result) == "1"
    @test [step.rule.name for step in steps] == ["1.1:1", "test:basic-exponents:4"]
end

@testitem "A nested optional slot keeps the root head selective" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: OSRDispatch, rule_head, candidate_positions

    @syms x

    rules = @load_osr("data/wildcards/1.4-nested-optional.json")

    # `SymbolicUtils` builds a default-valued matcher only where a `DefSlot` is
    # a direct argument, so a term whose own arguments carry none still
    # requires its head.  The canonical RUBI shape `Int((a. + b.*x)^m., x)` is
    # such a term: every optional operand sits below the `Int`.
    @test rule_head(rules[1]) === Integral

    # A root whose own argument is optional can match a term that lacks the
    # operation entirely, so it keeps no head requirement.
    @test rule_head(rules[2]) === nothing

    dispatch = OSRDispatch(rules)

    # The selective rule is not even tried against an unrelated head.
    @test !(1 in candidate_positions(dispatch, Sin(x)))
    # The unselective one always is.
    @test 2 in candidate_positions(dispatch, Sin(x))

    # Dispatching still reproduces a linear scan of every rule.
    for expr in (Integral(Power(Add(2, Multiply(3, x)), 4), x), Integral(x, x),
                 Multiply(5, Sin(x)), Sin(x), x)
        @test isequal(dispatch(expr), SymbolicUtils.Rewriters.Chain(rules)(expr))
    end
end

@testitem "Dispatch indexes the operand when every rule shares a head" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: OSRDispatch, candidate_positions, dispatch_key
    using SymbolicUtils

    @syms x

    rules = @load_osr("data/wildcards/1.9-deep-index.json")
    dispatch = OSRDispatch(rules)

    Int_ = OpenSymbolicRules.UninterpretedHeads.Int

    # Every RUBI rule is headed by `Int`, so the root head alone selects the
    # whole rule set. The head of the operand the rule integrates is what
    # actually distinguishes them.
    @test dispatch_key(rules[1]) === (Int_, Power)
    @test dispatch_key(rules[2]) === (Int_, Sin)
    # A rule whose operand is a bare slot requires no operand head, so it stays
    # a candidate whatever the integrand is.
    @test dispatch_key(rules[3]) === (Int_, nothing)
    # So does one whose operand carries an optional operand at its own root:
    # that pattern also matches a term lacking the operation entirely.
    @test dispatch_key(rules[4]) === (Int_, nothing)

    # A power integrand tries the power rules and the catch-all, not the sine one.
    @test candidate_positions(dispatch, Int_(Power(x, 3), x)) == [1, 3, 4]

    @test candidate_positions(dispatch, Int_(Sin(x), x)) == [2, 3, 4]

    # An integrand headed by nothing indexed still reaches the open rules.
    @test candidate_positions(dispatch, Int_(x, x)) == [3, 4]

    # Dispatching still reproduces a linear scan of every rule.
    for expr in (Int_(Power(x, 3), x), Int_(Sin(x), x), Int_(x, x), Power(x, 3), x)
        @test isequal(dispatch(expr), SymbolicUtils.Rewriters.Chain(rules)(expr))
    end
end
