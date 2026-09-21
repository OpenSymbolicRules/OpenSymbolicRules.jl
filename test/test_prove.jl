using TestItemRunner

@testitem "Proving an equivalence by joint normalisation" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    rules = vcat(@load_osr("data/1.1-basic-exponents.json"),
                 @load_osr("data/trig/1.1-pythagorean.json"))

    # Both sides reduce to the same normal form, so the equivalence holds.
    proof = prove(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 1, rules)
    @test proof isa OSRProof
    @test verified(proof)
    # The normal form is a symbolic literal, so it is compared by value.
    @test OpenSymbolicRules.osr_number(proof.normal_form) == 1
    @test [step.rule.name for step in proof.left_steps] == ["test:trig/1.1-pythagorean:1"]
    @test isempty(proof.right_steps)

    # Both sides need rewriting before they meet.
    proof = prove(Pow(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 1), Pow(x, 1), rules)
    @test !verified(proof)

    proof = prove(Pow(Add(Pow(Sin(x), 2), Pow(Cos(x), 2)), 1), Pow(1, 1), rules)
    @test verified(proof)
    @test !isempty(proof.left_steps)
    @test !isempty(proof.right_steps)
end

@testitem "A failed proof reports what each side reduced to" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    rules = @load_osr("data/1.1-basic-exponents.json")

    proof = prove(Pow(x, 1), y, rules)
    @test !verified(proof)
    @test proof.normal_form === nothing
    @test isequal(proof.left_normal_form, x)
    @test isequal(proof.right_normal_form, y)

    # Failing to find a rewrite path is not a proof of inequivalence, and the
    # report says so.
    @test occursin("not proved", sprint(show, proof))
    @test occursin("x", sprint(show, proof))
end

@testitem "Equivalence is decided up to bound variable names" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    rules = OSRRule[]

    proof = prove(Lambda(x, Sin(x)), Lambda(y, Sin(y)), rules)
    @test verified(proof)
    @test isempty(proof.left_steps)
    @test isempty(proof.right_steps)

    @test !verified(prove(Lambda(x, Sin(x)), Lambda(y, Sin(x)), rules))
end

@testitem "A proof is only as valid as its hypotheses" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Power(a, b)

    rules = @load_osr("data/1.2-nonzero-power.json")

    # `x^0 = 1` holds only for a nonzero `x`, so without that hypothesis there
    # is no proof.
    @test !verified(prove(Power(x, 0), 1, rules))
    @test verified(prove(Power(x, 0), 1, rules; assumptions=[IsNonzero(x)]))

    # The hypotheses the proof was established under are part of the proof.
    proof = prove(Power(x, 0), 1, rules; assumptions=[IsNonzero(x)])
    @test isequal(proof.assumptions, [IsNonzero(x)])
    @test occursin("under", sprint(show, proof))
end

@testitem "An equation can be proved directly" begin
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @syms Pow(a, b) Mul(a, b) Add(a, b) Sin(a) Cos(a)

    rules = @load_osr("data/trig/1.1-pythagorean.json")

    equation = Add(Pow(Sin(x), 2), Pow(Cos(x), 2)) ~ 1
    @test equation isa OpenSymbolicRules.Equation
    @test verified(prove(equation, rules))
end
