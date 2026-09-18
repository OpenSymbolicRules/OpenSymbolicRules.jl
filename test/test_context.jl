using TestItemRunner

@testitem "A domain hypothesis entails what the domain contains" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using DomainSets, IntervalSets
    using OpenSymbolicRules: is_positive, is_negative, is_nonzero, is_integer,
        is_real, is_complex

    @syms x

    assuming(x ∈ 2..5) do
        @test is_positive(x)
        @test is_nonzero(x)
        @test is_real(x)
        @test is_complex(x)
        # An interval of reals is not a proof of integrality.
        @test !is_integer(x)
        @test !is_negative(x)
    end

    assuming(x ∈ -5 .. -2) do
        @test is_negative(x)
        @test is_nonzero(x)
        @test !is_positive(x)
    end

    # An interval straddling zero decides nothing about the sign.
    assuming(x ∈ -1..1) do
        @test !is_positive(x)
        @test !is_negative(x)
        @test !is_nonzero(x)
        @test is_real(x)
    end

    # A closed bound at zero includes zero, so it is not a proof of positivity.
    assuming(x ∈ 0..Inf) do
        @test !is_positive(x)
        @test !is_nonzero(x)
        @test is_real(x)
    end
    assuming(x ∈ OpenInterval(0, Inf)) do
        @test is_positive(x)
        @test is_nonzero(x)
    end

    # `HalfLine()` is closed at zero; `NegativeHalfLine()` is open at it.
    assuming(x ∈ HalfLine()) do
        @test !is_positive(x)
    end
    assuming(x ∈ NegativeHalfLine()) do
        @test is_negative(x)
    end
end

@testitem "Number sets entail their containments" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using DomainSets
    using OpenSymbolicRules: is_integer, is_real, is_complex

    @syms x

    assuming(x ∈ Integers()) do
        @test is_integer(x)
        @test is_real(x)
        @test is_complex(x)
    end

    assuming(x ∈ RealNumbers()) do
        @test is_real(x)
        @test is_complex(x)
        @test !is_integer(x)
    end

    assuming(x ∈ ComplexNumbers()) do
        @test is_complex(x)
        @test !is_real(x)
    end

    # The same holds for a hypothesis written as a Julia type.
    assuming(x ∈ Int) do
        @test is_integer(x)
        @test is_real(x)
    end
    assuming(x ∈ Real) do
        @test is_real(x)
        @test !is_integer(x)
    end
    assuming(x ∈ Complex) do
        @test is_complex(x)
        @test !is_real(x)
    end
end

@testitem "Relational hypotheses entail their consequences" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: is_positive, is_negative, is_nonzero, is_integer, is_real

    @syms x

    assuming(IsPositive(x)) do
        @test is_positive(x)
        @test is_nonzero(x)
        @test is_real(x)
    end

    assuming(GreaterThan(x, 0)) do
        @test is_positive(x)
        @test is_nonzero(x)
    end
    assuming(GreaterThan(x, 5)) do
        @test is_positive(x)
    end
    # `x > -3` orders `x` without settling its sign.
    assuming(GreaterThan(x, -3)) do
        @test !is_positive(x)
        @test is_real(x)
    end

    assuming(LessThan(x, 0)) do
        @test is_negative(x)
        @test is_nonzero(x)
    end

    assuming(IsInteger(x)) do
        @test is_integer(x)
        @test is_real(x)
    end

    # Being nonzero says nothing about sign or domain.
    assuming(IsNonzero(x)) do
        @test is_nonzero(x)
        @test !is_positive(x)
        @test !is_negative(x)
        @test !is_real(x)
    end
end

@testitem "Rational hypotheses combine for conditional predicates" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using IntervalSets
    using OpenSymbolicRules: is_positive

    @syms x

    assuming(x ∈ 0..2) do
        @test !is_positive(x)
    end

    assuming(x ∈ 0..2) do
        assuming(IsNonzero(x)) do
            @test is_positive(x)
        end
    end
end

@testitem "A hypothesis constrains only the term it is about" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using DomainSets, IntervalSets
    using OpenSymbolicRules: is_positive, is_real

    @syms x y

    assuming(IsPositive(y)) do
        @test is_positive(y)
        @test !is_positive(x)
    end

    assuming(y ∈ 2..5) do
        @test !is_real(x)
    end

    # Hypotheses accumulate rather than replace one another.
    assuming(IsPositive(x)) do
        assuming(IsInteger(x)) do
            @test is_positive(x)
            @test OpenSymbolicRules.is_integer(x)
        end
    end
end

@testitem "An unconstrained symbol decides nothing and raises nothing" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: is_positive, is_negative, is_nonzero, is_integer,
        is_real, is_complex

    @syms x

    # Every domain predicate must answer for a bare symbol rather than throw.
    @test is_positive(x) === false
    @test is_negative(x) === false
    @test is_nonzero(x) === false
    @test is_integer(x) === false
    @test is_real(x) === false
    @test is_complex(x) === false
end

@testitem "A Symbolics membership hypothesis is understood" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using Symbolics
    using IntervalSets
    using OpenSymbolicRules: is_positive, is_real, normalize_fact

    @syms x

    # With Symbolics loaded, its `∈` method wins and builds a
    # `VarDomainPairing` rather than an `ElementOf`; a hypothesis written that
    # way must still constrain the term.
    fact = x ∈ 2..5
    @test !(fact isa OpenSymbolicRules.ElementOf)
    @test only(normalize_fact(fact)) isa OpenSymbolicRules.ElementOf

    assuming(fact) do
        @test is_positive(x)
        @test is_real(x)
    end

    @syms Abs(a)
    rule = @rule Abs(~v) => ~v where is_positive(~v)
    @test isequal(simplify(Abs(x), [rule]; assumptions=[x ∈ 2..5]), x)
end
