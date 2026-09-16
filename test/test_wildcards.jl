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

@testitem "Optional wildcards are rejected rather than misread" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: osr_to_expr

    # RUBI writes `a_.` for an operand that may be absent, which needs a matcher
    # that knows the identity element of the enclosing operation.  Compiling it
    # to an ordinary symbol named `a.` would silently produce a rule that can
    # never fire, so the loader refuses it instead.
    error = try
        osr_to_expr("a.")
        nothing
    catch caught
        caught
    end
    @test error isa ArgumentError
    @test occursin("optional", lowercase(error.msg))
    @test occursin("a.", error.msg)
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
