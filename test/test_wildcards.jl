using TestItemRunner

@testitem "OSR wildcard spellings compile to matcher patterns" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr

    # The package's own tilde spelling and the OSR v0.1 blank are the same slot.
    @test osr_to_expr("~x") == :(~x)
    @test osr_to_expr("x_") == :(~x)

    # A sequence wildcard is a segment.  `___` accepts an empty match, `__`
    # does not, so it carries the predicate that enforces it.
    @test osr_to_expr("xs___") == :(~~xs)
    @test osr_to_expr("xs__") ==
          Expr(:call, :~, Expr(:call, :~, Expr(:(::), :xs,
               GlobalRef(OpenSymbolicRules, :_nonempty_match))))

    # A typed blank carries the predicate for its declared domain.
    @test osr_to_expr("m_integer") ==
          Expr(:call, :~, Expr(:(::), :m, GlobalRef(OpenSymbolicRules, :IntegerQ)))
    @test osr_to_expr("q_rational") ==
          Expr(:call, :~, Expr(:(::), :q, GlobalRef(OpenSymbolicRules, :RationalQ)))

    # A name that merely contains an underscore is not a wildcard.
    @test osr_to_expr("x") == :x
    @test osr_to_expr("True") == true

    # An unknown domain is a rule-file error rather than a silently inert rule.
    @test_throws ArgumentError osr_to_expr("m_widget")
    @test_throws ArgumentError osr_to_expr("_")
    @test_throws ArgumentError osr_to_expr(".")
end

@testitem "Optional wildcards compile to a default-valued slot" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr, _optional_default
    using SymbolicUtils: DefSlot

    # RUBI writes `a.` for an operand that may be absent.  Matching one needs
    # the identity element of the enclosing operation, so the enclosing head
    # decides the default: `plus` contributes zero, `times` and the exponent of
    # `power` contribute one.
    @test _optional_default("openmath:arith1#plus", 1) == 0
    @test _optional_default("openmath:arith1#times", 2) == 1
    @test _optional_default("openmath:arith1#power", 2) == 1

    # A power's base is not an optional operand: only its exponent defaults.
    @test _optional_default("openmath:arith1#power", 1) === nothing
    # A head with no identity element supplies no default.
    @test _optional_default("openmath:arith1#gcd", 1) === nothing
    @test _optional_default(nothing, 1) === nothing

    # Inside a defaulting operation the wildcard becomes an interpolated
    # `DefSlot`, which `@rule` splices into the pattern verbatim.
    compiled = osr_to_expr(["Multiply", "a.", "x"])
    slot = compiled.args[2]
    @test slot isa Expr && slot.head === :$
    @test eval(slot.args[1]) isa DefSlot
    @test eval(slot.args[1]).defaultValue == 1
    @test eval(slot.args[1]).name === :a

    # A summand defaults to zero rather than one.
    @test eval(osr_to_expr(["Add", "a.", "x"]).args[2].args[1]).defaultValue == 0

    # An explicit default overrides the one the operation would supply.
    @test eval(osr_to_expr(["Add", "m.3", "x"]).args[2].args[1]).defaultValue == 3
end

@testitem "Optional wildcards without an identity element are rejected" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr

    # Outside any operation there is no identity element to fall back on, so
    # compiling `a.` to an ordinary symbol named `a.` would silently produce a
    # rule that can never fire.  The loader refuses it instead.
    error = try
        osr_to_expr("a.")
        nothing
    catch caught
        caught
    end
    @test error isa ArgumentError
    @test occursin("optional", lowercase(error.msg))
    @test occursin("a.", error.msg)

    # The same holds under a head that has no identity element, and under the
    # base of a power, where an absent operand has no meaning.
    @test_throws ArgumentError osr_to_expr(["Gcd", "a.", "b_"])
    @test_throws ArgumentError osr_to_expr(["Power", "a.", "m_"])
end

@testitem "Optional wildcards match present and absent operands" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y

    rules = @load_osr("data/wildcards/1.2-optional-forms.json")

    # An absent factor binds the multiplicative identity.
    @test isequal(rules[1](Multiply(3, x)), 3)
    @test isequal(rules[1](x), 1)

    # An absent exponent binds one.
    @test isequal(rules[2](Power(x, 4)), 4)
    @test isequal(rules[2](x), 1)

    # An absent summand binds zero, not one.
    @test isequal(rules[3](Add(7, x)), 7)
    @test isequal(rules[3](x), 0)

    # The canonical RUBI binomial `(a. + b.*x)^m.` matches the full shape and
    # every degenerate one, binding the identity of each absent operand.
    @test isequal(rules[4](Power(Add(2, Multiply(3, x)), 4)), [2, 3, 4])
    @test isequal(rules[4](x), [0, 1, 1])
    @test isequal(rules[4](Add(2, x)), [2, 1, 1])

    # An n-ary associative head normalizes to left-associated binary terms,
    # which keeps the default available at the position the rule declared it.
    @test isequal(rules[5](Add(Add(7, x), y)), 7)
    @test isequal(rules[5](Add(x, y)), 0)

    # A constraint reads the binding the optional slot made, including the
    # default one, so a defaulted operand is still weighed.
    @test isequal(rules[6](Multiply(5, y)), 5)
    @test isequal(rules[6](y), 1)
end

@testitem "Sequence and typed wildcards match as declared" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Pow(a, b) Gcd(a, b, c)

    rules = @load_osr("data/wildcards/1.1-wildcard-forms.json")

    # `ws___` accepts an empty match, so the pattern covers the whole term.
    @test isequal(rules[1](Gcd(1, 2, 3)), 1)
    # `ws__` requires at least one trailing argument, which this term lacks.
    @test rules[2](Gcd(1, 2, 3)) === nothing
    # With a shorter prefix the same segment binds a non-empty tail.
    @test isequal(rules[3](Gcd(1, 2, 3)), 1)

    # A typed blank only matches a value of its declared domain.
    @test isequal(rules[4](Pow(x, 2)), 2)
    @test rules[4](Pow(x, 1 // 2)) === nothing
end

@testitem "A structural collection needs no per-file OpenMath declaration" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: _validate_openmath_semantics

    # `List` is part of the OSR expression language rather than domain
    # vocabulary: it compiles to a host collection, not to a mathematical term.
    # Requiring every rule file to rebind it adds no semantic guarantee.
    structural = Dict(
        "identity" => "test:structural",
        "semantics" => Dict("Add" => "openmath:arith1#plus"),
        "rules" => [Dict(
            "id" => 1,
            "pattern" => ["Add", "a_", "b_"],
            "constraints" => Any[["FreeQ", ["List", "a_"], "b_"]],
            "result" => "a_",
        )],
    )
    @test _validate_openmath_semantics([structural]) === nothing

    # A mathematical operation still has to be declared, so the semantic
    # closure the domain repositories check is not weakened.
    undeclared = Dict(
        "identity" => "test:undeclared",
        "semantics" => Dict("Add" => "openmath:arith1#plus"),
        "rules" => [Dict(
            "id" => 1,
            "pattern" => ["Add", "a_", "b_"],
            "constraints" => Any[],
            "result" => ["Multiply", "a_", "b_"],
        )],
    )
    @test_throws ArgumentError _validate_openmath_semantics([undeclared])
end

@testitem "A wildcard in operator position is a binding, not an operator" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr, _validate_openmath_semantics
    using SymbolicUtils

    # OSR-X-004 allows a pattern variable in operator position, as in the RUBI
    # rules that match any of the six trigonometric heads at once.  It names a
    # binding, so it needs no OpenMath symbol.
    @test osr_to_expr(["f_", "x"]) == Expr(:call, :(~f), :x)

    # An optional wildcard has no meaning in operator position: an absent
    # operator has no identity element to fall back on.
    @test_throws ArgumentError osr_to_expr(["f.", "x"])

    @syms x y
    rules = @load_osr("data/wildcards/1.3-head-wildcard.json")

    # The head the wildcard matched is reusable in the result.
    @test isequal(rules[1](Sin(x)), Multiply(2, Sin(x)))
    @test isequal(rules[1](Cos(x)), Multiply(2, Cos(x)))

    @test isequal(rules[2](Add(x, y)), x)
end

@testitem "A result refers to a binding by its bare name" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: _pattern_bindings
    using SymbolicUtils

    # RUBI spells a wildcard `m_` where the pattern declares it and `m` where
    # the result or a constraint refers to it. A bare name the pattern bound is
    # therefore a reference to that binding, not a free symbol.
    @test _pattern_bindings(["Power", "x_", "m."]) == Set([:x, :m])
    @test _pattern_bindings(["f_", ["Multiply", "a.", "xs__"]]) == Set([:f, :a, :xs])
    @test _pattern_bindings(["Power", "y_", 2]) == Set([:y])

    @syms y k
    rules = @load_osr("data/wildcards/1.5-bare-references.json")

    # Every bare name the pattern bound resolves to what it matched, in the
    # result and in the guard alike.
    @test isequal(rules[1](Power(y, 3)),
                  Multiply(Power(y, Add(3, 1)), Power(Add(3, 1), -1)))
    # The guard reads the same binding, so the excluded exponent is rejected.
    @test rules[1](Power(y, -1)) === nothing
    # An absent exponent still binds the default.
    @test isequal(rules[1](y), Multiply(Power(y, Add(1, 1)), Power(Add(1, 1), -1)))

    # A name the pattern never bound stays a free symbol.
    @test isequal(rules[2](Power(y, 2)), Multiply(y, k))

    # A head bound by the pattern is referable by its bare name.
    @test isequal(rules[3](Sin(y)), Sin(Multiply(2, y)))
end

@testitem "A declared head the host does not implement stays uninterpreted" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms w

    # Every operator in a rule file carries an OpenMath symbol, so a head this
    # package has no Julia implementation for still has a definite meaning. It
    # denotes an operation that cannot be evaluated here, which is an
    # unevaluated term — not a rule that raises an undefined-variable error the
    # moment it fires.
    @test !isdefined(@__MODULE__, :PolynomialRemainder)
    rules = @load_osr("data/wildcards/1.6-uninterpreted-head.json")

    rewritten = rules[1](Power(w, 2))
    @test rewritten !== nothing
    @test SymbolicUtils.operation(rewritten) === PolynomialRemainder
    @test isequal(rewritten, PolynomialRemainder(w, w, 2))

    # A head the package does implement keeps its implementation.
    @test Multiply === OpenSymbolicRules.Multiply
end
