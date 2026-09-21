using TestItemRunner

@testitem "canonical folds what is closed and drops what is idle" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: canonical
    using SymbolicUtils

    @syms x y

    # A closed arithmetic subterm has one value, and carrying it around
    # unevaluated is what makes a correct answer read as a wrong one: a
    # derivative rule leaves `x^(3-1)`, and nothing matches that against `x^2`.
    @test isequal(canonical(Power(x, Add(3, -1))), Power(x, 2))
    @test isequal(canonical(Add(2, 3)), 5)

    # A rational whose denominator is one is that integer.
    @test isequal(canonical(Multiply(x, 4 // 4)), x)
    @test OpenSymbolicRules.osr_number(canonical(Add(6 // 3, 0))) == 2

    # An identity operand does nothing and goes; this is sound for every
    # additive group and every multiplicative monoid, matrices included.
    @test isequal(canonical(Add(x, 0)), x)
    @test isequal(canonical(Multiply(x, 1)), x)
    @test isequal(canonical(Power(x, 1)), x)

    # `Power(x, 0)` stays: it is one only where `x` is nonzero, and nothing
    # here established that.
    @test isequal(canonical(Power(x, 0)), Power(x, 0))

    # Nothing to do is returned unchanged.
    @test isequal(canonical(Add(x, y)), canonical(Add(x, y)))
    @test isequal(canonical(x), x)
end

@testitem "canonical orders a sum and leaves a product alone" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: canonical, canonically_equal
    using SymbolicUtils

    @syms x y z

    # Addition commutes in every additive group, so a deterministic order over
    # the summands is sound and is what lets two answers be compared.
    @test isequal(canonical(Add(x, y)), canonical(Add(y, x)))
    @test isequal(canonical(Add(Add(x, y), z)), canonical(Add(z, Add(y, x))))

    # Multiplication does not: an OSR expression carries no shape, so a factor
    # may be a matrix and reordering would be unsound. The order is kept.
    @test !isequal(canonical(Multiply(x, y)), canonical(Multiply(y, x)))

    # Which is exactly what `canonically_equal` reports.
    @test canonically_equal(Add(x, y), Add(y, x))
    @test canonically_equal(Power(x, Add(3, -1)), Power(x, 2))
    @test !canonically_equal(Multiply(x, y), Multiply(y, x))
    @test !canonically_equal(Add(x, y), Add(x, z))
end

@testitem "canonical is idempotent and leaves an unevaluated operation standing" begin
    using OpenSymbolicRules
    using OpenSymbolicRules: canonical
    using SymbolicUtils

    @syms x
    @syms Opaque(a)

    for expression in (Add(Multiply(2, 3), x), Power(x, Add(2, -1)),
                       Multiply(Add(x, 0), 1), Opaque(Add(1, 1)))
        once = canonical(expression)
        @test isequal(canonical(once), once)
    end

    # A head the package does not evaluate keeps its operands normalized and
    # itself intact: normalizing is not evaluating.
    @test isequal(canonical(Opaque(Add(1, 1))), Opaque(2))
end
