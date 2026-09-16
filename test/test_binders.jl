using TestItemRunner

@testitem "Lexical scope of binder terms" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: bound_variables, binder_body, free_variables

    @syms x y c

    @test bound_variables(Lambda(x, Sin(x))) == [:x]
    @test bound_variables(Forall([:x, :y], And(x, y))) == [:x, :y]
    @test bound_variables(Exists([:x], x)) == [:x]
    @test bound_variables(Sin(x)) === nothing
    @test bound_variables(x) === nothing

    @test isequal(binder_body(Lambda(x, Sin(x))), Sin(x))

    @test free_variables(x) == Set([:x])
    @test free_variables(Add(x, y)) == Set([:x, :y])
    @test free_variables(2) == Set{Symbol}()

    # A bound variable is not free in the term that binds it.
    @test free_variables(Lambda(x, Sin(x))) == Set{Symbol}()
    @test free_variables(Lambda(x, Add(x, y))) == Set([:y])
    @test free_variables(Forall([:x], And(x, y))) == Set([:y])

    # Only the innermost binder of a name captures it.
    @test free_variables(Lambda(x, Lambda(y, Add(x, y)))) == Set{Symbol}()
    @test free_variables(Add(Lambda(x, x), x)) == Set([:x])
end

@testitem "FreeQ respects binders" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y c

    # The classic structural cases are unchanged.
    @test FreeQ(c, x)
    @test !FreeQ(Sin(x), x)
    @test FreeQ(Sin(y), x)

    # A bound occurrence is not an occurrence of the free variable, so a term
    # that only binds `x` is free of `x`.
    @test FreeQ(Lambda(x, Sin(x)), x)
    @test !FreeQ(Lambda(y, Sin(x)), x)
    @test FreeQ(Forall([:x], x), x)
end

@testitem "Capture-avoiding substitution" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: osr_substitute, free_variables, alpha_equivalent

    @syms x y z c

    @test isequal(osr_substitute(x, x => c), c)
    @test isequal(osr_substitute(Sin(x), x => c), Sin(c))
    @test isequal(osr_substitute(Add(x, y), x => c), Add(c, y))
    @test isequal(osr_substitute(y, x => c), y)

    # A shadowed variable is left alone.
    @test isequal(osr_substitute(Lambda(x, Sin(x)), x => c), Lambda(x, Sin(x)))

    # Substituting under a binder that does not shadow the variable.
    @test isequal(osr_substitute(Lambda(y, Add(x, y)), x => c), Lambda(y, Add(c, y)))

    # The replacement's free `y` must not be captured by the binder of `y`:
    # the binder is renamed first.
    captured = osr_substitute(Lambda(y, Add(x, y)), x => y)
    @test free_variables(captured) == Set([:y])
    @test !isequal(captured, Lambda(y, Add(y, y)))
    @test alpha_equivalent(captured, Lambda(z, Add(y, z)))

    # The same protection applies to quantifiers.
    quantified = osr_substitute(Forall([:y], And(x, y)), x => y)
    @test free_variables(quantified) == Set([:y])
    @test !isequal(quantified, Forall([:y], And(y, y)))
end

@testitem "Alpha equivalence" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: alpha_equivalent

    @syms x y z

    @test alpha_equivalent(Lambda(x, Sin(x)), Lambda(y, Sin(y)))
    @test !alpha_equivalent(Lambda(x, Sin(x)), Lambda(y, Sin(x)))
    @test alpha_equivalent(Lambda(x, Lambda(y, Add(x, y))), Lambda(y, Lambda(x, Add(y, x))))
    @test alpha_equivalent(Forall([:x], x), Forall([:y], y))
    @test !alpha_equivalent(Forall([:x, :y], Add(x, y)), Forall([:x], x))

    # Free variables are compared by name, not renamed.
    @test alpha_equivalent(Add(x, y), Add(x, y))
    @test !alpha_equivalent(Add(x, y), Add(y, x))
    @test alpha_equivalent(Sin(z), Sin(z))
end
