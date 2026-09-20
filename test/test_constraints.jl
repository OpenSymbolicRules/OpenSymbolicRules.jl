using TestItemRunner

@testitem "Numeric folding of canonical arithmetic heads" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: osr_number

    @syms x

    @test osr_number(3) == 3
    @test osr_number(Add(1, 2)) == 3
    @test osr_number(Multiply(2, Add(1, 2))) == 6
    @test osr_number(Subtract(1, 4)) == -3
    @test osr_number(Divide(1, 4)) == 1 // 4

    # `Power(2, -1)` is how OSR spells a reciprocal.  Folding it must stay
    # exact rather than falling back to floating point.
    @test osr_number(Power(2, -1)) == 1 // 2
    @test osr_number(Power(2, 10)) == 1024

    # Anything that is not a closed arithmetic expression has no value.
    @test osr_number(x) === nothing
    @test osr_number(Add(x, 1)) === nothing
    @test osr_number(Sin(1)) === nothing

    # An undefined value is not a number.
    @test osr_number(Power(0, -1)) === nothing
    @test osr_number(Divide(1, 0)) === nothing
end

@testitem "Comparison predicates are conservative" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: EqQ, NeQ, GtQ, LtQ, GeQ, LeQ

    @syms x y

    @test EqQ(2, 2)
    @test EqQ(Add(1, 1), 2)
    @test !EqQ(2, 3)
    # Syntactic identity proves equality; structural difference proves nothing.
    @test EqQ(x, x)
    @test !EqQ(x, y)
    @test !EqQ(x, 0)

    @test NeQ(2, 3)
    @test !NeQ(2, 2)
    @test !NeQ(x, 0)

    @test GtQ(3, 2)
    @test !GtQ(2, 3)
    @test !GtQ(x, 0)
    @test LtQ(2, 3)
    @test GeQ(3, 3)
    @test LeQ(3, 3)

    # RUBI chains a three-argument comparison: GtQ(u, v, w) is u > v > w.
    @test GtQ(3, 2, 1)
    @test !GtQ(3, 1, 2)
    @test LtQ(1, 2, 3)

    # A complex value is not ordered.
    @test !GtQ(1 + 2im, 0)
end

@testitem "Integer-qualified and numeric-domain predicates" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: IGtQ, ILtQ, IGeQ, ILeQ, IntegersQ, RationalQ,
        FractionQ, HalfIntegerQ, PosQ, NegQ, FalseQ, AtomQ

    @syms x

    @test IGtQ(3, 0)
    @test !IGtQ(3 // 2, 0)
    @test !IGtQ(-1, 0)
    @test ILtQ(-2, 0)
    @test IGeQ(0, 0)
    @test ILeQ(0, 0)

    @test IntegersQ(1, 2, 3)
    @test !IntegersQ(1, 3 // 2)
    @test !IntegersQ(1, x)

    @test RationalQ(1, 3 // 2)
    @test !RationalQ(1.5)
    @test FractionQ(3 // 2)
    @test !FractionQ(2)
    @test HalfIntegerQ(3 // 2, -1 // 2)
    @test !HalfIntegerQ(1)

    @test PosQ(Power(2, -1))
    @test !PosQ(-1)
    @test !PosQ(x)
    @test assuming(IsPositive(x)) do
        PosQ(x)
    end
    @test NegQ(-3)
    @test !NegQ(x)

    @test FalseQ(false)
    @test !FalseQ(true)
    @test !FalseQ(x)

    @test AtomQ(x)
    @test AtomQ(2)
    @test !AtomQ(Add(x, 1))
end

@testitem "Structural and polynomial predicates" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: SumQ, ProductQ, PowerQ, MemberQ, PolynomialQ,
        PolyQ, LinearQ, QuadraticQ

    @syms x a b c

    @test SumQ(Add(x, 1))
    @test !SumQ(Multiply(x, 2))
    @test ProductQ(Multiply(x, 2))
    @test PowerQ(Power(x, 2))
    @test !PowerQ(x)

    @test MemberQ([Sin, Cos], Sin)
    @test !MemberQ([Sin, Cos], Tan)

    @test PolynomialQ(Add(Multiply(a, Power(x, 2)), b), x)
    @test !PolynomialQ(Power(x, -1), x)
    @test !PolynomialQ(Sin(x), x)

    @test PolyQ(Add(Multiply(a, Power(x, 2)), b), x)
    @test PolyQ(Add(Multiply(a, Power(x, 2)), b), x, 2)
    @test !PolyQ(Add(Multiply(a, Power(x, 2)), b), x, 1)

    @test LinearQ(Add(a, Multiply(b, x)), x)
    @test !LinearQ(Add(a, Multiply(b, Power(x, 2))), x)
    # A constant is not linear in x.
    @test !LinearQ(a, x)

    @test QuadraticQ(Add(Add(a, Multiply(b, x)), Multiply(c, Power(x, 2))), x)
    @test !QuadraticQ(Add(a, Multiply(b, x)), x)
end

@testitem "Constraint combinators compile to Julia control flow" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x m
    @syms Int(a, b) Pow(a, b) Mul(a, b) Plus(a, b)

    rules = @load_osr("data/constraints/1.1-predicate-combinators.json")

    # `Not(IntegerQ(m))` must call the Julia predicate and negate it, not build
    # a symbolic `Not` term.
    @test rules[1](Pow(x, 2)) === nothing
    @test isequal(rules[1](Pow(x, 3 // 2)), 3 // 2)

    # `Or(..., And(...))` nests, and the guard must remain conservative for a
    # symbol with no hypothesis.
    @test rules[2](Pow(x, m)) === nothing
    @test isequal(rules[2](Pow(x, 2)), 2)
    @test assuming(IsPositive(m)) do
        isequal(rules[2](Pow(x, m)), m)
    end
end

@testitem "Predicate names resolve inside the rule library" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Pow(a, b)

    # A rule file may use a predicate the library does not define; the name is
    # then resolved in the module that loaded the rules.
    EvenIntegerQ(value) = value isa Integer && iseven(value)
    rules = @load_osr("data/constraints/1.2-host-predicate.json")
    @test isequal(rules[1](Pow(x, 2)), 2)
    @test rules[1](Pow(x, 3)) === nothing
end

@testitem "Assumption predicates fold closed arithmetic" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: is_positive, is_negative, is_nonzero, is_integer,
        is_numeric, is_real, is_complex

    @syms x

    # A guarded rewrite must not be skipped merely because its constraint is
    # spelled as an arithmetic expression rather than as a literal.
    @test is_numeric(Add(1, 2))
    @test is_integer(Add(1, 2))
    @test !is_integer(Power(2, -1))
    @test is_positive(Power(2, -1))
    @test is_negative(Subtract(1, 4))
    @test is_nonzero(Subtract(1, 4))
    @test !is_nonzero(Subtract(4, 4))
    @test is_real(Divide(1, 4))
    @test is_complex(Divide(1, 4))

    # A complex number is neither positive nor negative.
    @test !is_positive(Multiply(2, im))
    @test !is_negative(Multiply(2, im))
    @test !is_real(Multiply(2, im))
    @test is_complex(Multiply(2, im))

    # Nothing about an unconstrained symbol is decidable.
    @test !is_numeric(x)
    @test !is_nonzero(x)
end

@testitem "Rule-language forms inside a constraint are not domain operators" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: _validate_openmath_semantics, _compile_constraint

    # `Condition` pairs a pattern with the test that guards it — OSR's spelling
    # of a guarded pattern.  It belongs to the rule language, so neither it nor
    # the predicates inside its test need an OpenMath symbol.
    guarded = Dict(
        "identity" => "test:guarded",
        "semantics" => Dict("Multiply" => "openmath:arith1#times"),
        "rules" => [Dict(
            "id" => 1,
            "pattern" => ["Multiply", "a_", "x_"],
            "constraints" => Any[["MatchQ", "a_",
                ["Condition", ["Multiply", "b_", "x_"], ["FreeQ", "b_", "x_"]]]],
            "result" => "a_",
        )],
    )
    @test _validate_openmath_semantics([guarded]) === nothing

    # A mathematical operation inside the guarded pattern is still domain
    # vocabulary and still has to be declared.
    undeclared = deepcopy(guarded)
    undeclared["rules"][1]["constraints"][1][3][2] = ["Divide", "b_", "x_"]
    @test_throws ArgumentError _validate_openmath_semantics([undeclared])

    # `If` selects between two tests, so all three of its arguments are
    # constraints rather than expressions.
    branching = Dict(
        "identity" => "test:branching",
        "semantics" => Dict("Multiply" => "openmath:arith1#times"),
        "rules" => [Dict(
            "id" => 1,
            "pattern" => ["Multiply", "a_", "x_"],
            "constraints" => Any[["If", ["RationalQ", "a_"], ["GtQ", "a_", 1],
                                        ["IntegerQ", "a_"]]],
            "result" => "a_",
        )],
    )
    @test _validate_openmath_semantics([branching]) === nothing

    # It compiles to Julia control flow over booleans, never to a symbolic term.
    compiled = _compile_constraint(
        ["If", ["RationalQ", "a_"], ["GtQ", "a_", 1], ["IntegerQ", "a_"]],
        Dict{String,String}())
    @test compiled isa Expr && compiled.head === :if
end

@testitem "A predicate the host cannot decide leaves its guard unproved" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: UnprovedConstraint
    using SymbolicUtils

    @syms y

    # `PseudoBinomialPairQ` is one of the 43 RUBI predicates this package does
    # not implement. A predicate answers `true` only when the property is
    # established, and one that cannot be evaluated establishes nothing — so its
    # guard must leave the rewrite unapplied rather than raise.
    @test !isdefined(@__MODULE__, :PseudoBinomialPairQ)
    rules = @load_osr("data/constraints/1.5-unproved.json")

    @test rules[1](Power(y, 2)) === nothing

    # Negation does not turn "not established" into a licence to rewrite: an
    # undecidable predicate stays undecidable under `Not`.
    @test rules[2](Power(y, 2)) === nothing

    # A disjunction is still established by a branch that holds, because the
    # guard short-circuits before reaching the undecidable one.
    @test isequal(rules[3](Power(y, 2)), Multiply(y, 2))
    # With no integer exponent the remaining branch is undecidable, so nothing
    # is established.
    @test rules[3](Power(y, 1 // 2)) === nothing

    # A conjunction needs every branch, so one undecidable branch is fatal.
    @test rules[4](Power(y, 2)) === nothing

    # A guard that names only implemented predicates is unaffected.
    @test isequal(rules[5](Power(y, 2)), 2)
    @test rules[5](Power(y, 1 // 2)) === nothing

    # The rule is still loaded, with its identity and provenance intact.
    @test length(rules) == 5
    @test endswith(rules[1].name, ":1")
    @test rules[3].provenance["method"] == "manual"

    # The exception exists and names the predicate, so a host can report it.
    error = UnprovedConstraint("PseudoBinomialPairQ")
    @test occursin("PseudoBinomialPairQ", sprint(showerror, error))
end

@testitem "A host may supply a predicate the package does not implement" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms y

    # A predicate resolved by the loading module is used as it stands, which is
    # how a host completes the vocabulary without changing this library.
    PseudoBinomialPairQ(u, m) = true
    rules = @load_osr("data/constraints/1.5-unproved.json")

    @test isequal(rules[1](Power(y, 2)), y)
end
