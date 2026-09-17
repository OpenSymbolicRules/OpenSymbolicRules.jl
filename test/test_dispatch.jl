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
    @test candidate_positions(dispatch, Pow(x, 1)) == [1, 3, 4]
    # Only the `Mul` rule is a candidate for a product.
    @test candidate_positions(dispatch, Mul(x, x)) == [2]
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
