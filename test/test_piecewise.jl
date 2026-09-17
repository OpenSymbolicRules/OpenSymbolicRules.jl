using TestItemRunner

@testitem "Piecewise branches and their conditions" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: piecewise_pieces

    @syms x

    expr = Piecewise([Piece(x, IsPositive(x)), Otherwise(Multiply(-1, x))])
    pieces = piecewise_pieces(expr)

    @test length(pieces) == 2
    @test isequal(pieces[1].value, x)
    @test isequal(pieces[1].condition, IsPositive(x))
    @test isequal(pieces[2].value, Multiply(-1, x))
    # The final branch carries no condition of its own.
    @test pieces[2].condition === nothing

    @test piecewise_pieces(x) === nothing
end

@testitem "A branch is selected only when its condition is decided" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: select_piece

    @syms x

    absolute = Piecewise([Piece(x, IsPositive(x)), Otherwise(Multiply(-1, x))])

    # Nothing is known about `x`, so no branch may be taken.
    @test isequal(select_piece(absolute), absolute)

    # A hypothesis settles the first condition.
    @test assuming(IsPositive(x)) do
        isequal(select_piece(absolute), x)
    end

    # A closed arithmetic condition is decided by value, and a decided-false
    # branch is skipped so that the fallback applies.
    # The selected value is a symbolic literal, so it is compared by value.
    numeric = Piecewise([Piece(1, GreaterThan(Subtract(1, 4), 0)), Otherwise(2)])
    @test OpenSymbolicRules.osr_number(select_piece(numeric)) == 2

    taken = Piecewise([Piece(1, GreaterThan(Add(1, 2), 0)), Otherwise(2)])
    @test OpenSymbolicRules.osr_number(select_piece(taken)) == 1

    # An undecided earlier branch blocks a later one, even a decidable one.
    blocked = Piecewise([Piece(1, IsPositive(x)), Piece(2, GreaterThan(Add(1, 2), 0)), Otherwise(3)])
    @test isequal(select_piece(blocked), blocked)
end

@testitem "Piecewise conditions combine with three-valued logic" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: decide_condition

    @syms x

    @test decide_condition(true) === true
    @test decide_condition(false) === false
    @test decide_condition(IsPositive(x)) === nothing

    @test decide_condition(GreaterThan(Add(1, 2), 0)) === true
    @test decide_condition(GreaterThan(Subtract(1, 4), 0)) === false
    @test decide_condition(IsPositive(Power(2, -1))) === true
    @test decide_condition(IsNegative(Power(2, -1))) === false

    # An unknown operand keeps a conjunction undecided unless it is already
    # settled by a decided operand.
    @test decide_condition(And(IsPositive(x), false)) === false
    @test decide_condition(And(IsPositive(x), true)) === nothing
    @test decide_condition(Or(IsPositive(x), true)) === true
    @test decide_condition(Or(IsPositive(x), false)) === nothing
    @test decide_condition(Not(true)) === false
    @test decide_condition(Not(IsPositive(x))) === nothing

    # A hypothesis decides a condition, and its negation follows.
    @test assuming(IsPositive(x)) do
        decide_condition(IsPositive(x)) === true && decide_condition(Not(IsPositive(x))) === false
    end
end

@testitem "Scope analysis reaches into collection arguments" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: free_variables, osr_substitute, alpha_equivalent, occurs_free

    @syms x y c

    expr = Piecewise([Piece(x, IsPositive(x)), Otherwise(y)])

    # A branch vector is part of the expression, so its variables are free.
    @test free_variables(expr) == Set([:x, :y])
    @test occurs_free(expr, :y)
    @test !FreeQ(expr, x)

    substituted = osr_substitute(expr, x => c)
    @test free_variables(substituted) == Set([:c, :y])
    @test isequal(substituted, Piecewise([Piece(c, IsPositive(c)), Otherwise(y)]))

    # A bound variable inside a branch is still bound.
    bound = Lambda(x, Piecewise([Piece(x, IsPositive(x)), Otherwise(y)]))
    @test free_variables(bound) == Set([:y])
    @test alpha_equivalent(bound, Lambda(c, Piecewise([Piece(c, IsPositive(c)), Otherwise(y)])))
end

@testitem "Piecewise expressions load from OSR JSON" begin
    using OpenSymbolicRules
    using SymbolicUtils
    using OpenSymbolicRules: select_piece

    @syms x
    @syms Sqrt(a) Pow(a, b)

    rules = @load_osr("data/piecewise/1.1-absolute-value.json")

    # sqrt(x^2) keeps its validity conditions instead of collapsing to x.
    result = rules[1](Sqrt(Pow(x, 2)))
    @test isequal(result, Piecewise([Piece(x, IsPositive(x)), Otherwise(Multiply(-1, x))]))
    @test isequal(select_piece(result), result)
    @test assuming(IsPositive(x)) do
        isequal(select_piece(result), x)
    end
end
