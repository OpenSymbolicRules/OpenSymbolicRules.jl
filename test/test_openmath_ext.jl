using TestItems

const _OPENMATH_TEST_PROJECT = read(joinpath(@__DIR__, "Project.toml"), String)
if occursin(r"(?m)^OpenMath\s*=", _OPENMATH_TEST_PROJECT)

@testitem "OpenMath extension exports and imports core symbolic expressions" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    object = OpenSymbolicRules.to_openmath(Add(x, 1))

    @test object isa OpenMath.OMApplication
    @test object.applicant == OpenMath.OMSymbol("arith1", "plus")
    @test object.arguments[1] == OpenMath.OMVariable("x")
    @test object.arguments[2] == OpenMath.OMInteger(1)
    @test OpenMath.isvalid_openmath(object)

    recovered = OpenSymbolicRules.from_openmath(object)
    @test SymbolicUtils.operation(recovered) === Add
    @test SymbolicUtils.arguments(recovered)[2] == 1
    @test SymbolicUtils.getname(SymbolicUtils.arguments(recovered)[1]) == :x
end

@testitem "OpenMath extension preserves exact rational literals" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    object = OpenSymbolicRules.to_openmath(Power(x, 3 // 2))

    @test object.applicant == OpenMath.OMSymbol("arith1", "power")
    @test object.arguments[2].applicant == OpenMath.OMSymbol("nums1", "rational")
    @test OpenSymbolicRules.from_openmath(object) |> SymbolicUtils.arguments |> last == 3 // 2
end

@testitem "OpenMath extension preserves square-root arity" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    object = OpenSymbolicRules.to_openmath(Sqrt(x))

    @test object.applicant == OpenMath.OMSymbol("arith1", "root")
    @test object.arguments[2] == OpenMath.OMInteger(2)
    @test SymbolicUtils.operation(OpenSymbolicRules.from_openmath(object)) === Sqrt
end

@testitem "OpenMath extension preserves lambda-bound derivatives" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    expression = Derivative(Lambda(x, Power(x, 2)))
    object = OpenSymbolicRules.to_openmath(expression)

    @test object.applicant == OpenMath.OMSymbol("calculus1", "diff")
    @test object.arguments[1] isa OpenMath.OMBinding
    @test object.arguments[1].binder == OpenMath.OMSymbol("fns1", "lambda")
    @test only(object.arguments[1].variables).name == "x"

    recovered = OpenSymbolicRules.from_openmath(object)
    @test SymbolicUtils.operation(recovered) === Derivative
    @test SymbolicUtils.operation(only(SymbolicUtils.arguments(recovered))) === Lambda
end

@testitem "OpenMath extension preserves ordered piecewise branches" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x y
    expression = Piecewise([Piece(x, GreaterThan(x, 0)), Otherwise(y)])
    object = OpenSymbolicRules.to_openmath(expression)

    @test object.applicant == OpenMath.OMSymbol("piece1", "piecewise")
    @test object.arguments[1].applicant == OpenMath.OMSymbol("piece1", "piece")
    @test object.arguments[2].applicant == OpenMath.OMSymbol("piece1", "otherwise")

    recovered = OpenSymbolicRules.from_openmath(object)
    @test isequal(recovered, expression)
end

@testitem "OpenMath extension preserves ordered relations" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    for (expression, symbol) in (
        (GreaterThan(x, 0), OpenMath.OMSymbol("relation1", "gt")),
        (LessThan(x, 1), OpenMath.OMSymbol("relation1", "lt")),
    )
        object = OpenSymbolicRules.to_openmath(expression)
        @test object.applicant == symbol
        @test isequal(OpenSymbolicRules.from_openmath(object), expression)
    end
end

@testitem "OpenMath extension keeps OSR collections distinct from vectors" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    collection = Any[x, 1, Sin(x)]
    object = OpenSymbolicRules.to_openmath(collection)

    @test object.applicant == OpenMath.OMSymbol("list1", "list")
    @test object.arguments[2] == OpenMath.OMInteger(1)
    @test isequal(OpenSymbolicRules.from_openmath(object), collection)
end

@testitem "OpenMath extension preserves canonical limits" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    expression = Limit(0, BothSides, Lambda(x, Divide(Sin(x), x)))
    object = OpenSymbolicRules.to_openmath(expression)

    @test object.applicant == OpenMath.OMSymbol("limit1", "limit")
    @test object.arguments[2] == OpenMath.OMSymbol("limit1", "both_sides")
    @test object.arguments[3] isa OpenMath.OMBinding
    @test isequal(OpenSymbolicRules.from_openmath(object), expression)
end

@testitem "OpenMath extension preserves universal exact constants" begin
    using OpenMath
    using OpenSymbolicRules

    @test OpenSymbolicRules.to_openmath(π) == OpenMath.OMSymbol("nums1", "pi")
    @test OpenSymbolicRules.to_openmath(ℯ) == OpenMath.OMSymbol("nums1", "e")
    @test OpenSymbolicRules.to_openmath(im) == OpenMath.OMSymbol("complex1", "i")

    @test OpenSymbolicRules.from_openmath(OpenMath.OMSymbol("nums1", "pi")) === π
    @test OpenSymbolicRules.from_openmath(OpenMath.OMSymbol("nums1", "e")) === ℯ
    @test OpenSymbolicRules.from_openmath(OpenMath.OMSymbol("complex1", "i")) === im
end

@testitem "OpenMath extension covers trigonometric and hyperbolic heads" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    for (expression, symbol) in (
        (Cot(x), OpenMath.OMSymbol("transc1", "cot")),
        (Asec(x), OpenMath.OMSymbol("transc1", "arcsec")),
        (Csch(x), OpenMath.OMSymbol("transc1", "csch")),
        (Acoth(x), OpenMath.OMSymbol("transc1", "arccoth")),
    )
        object = OpenSymbolicRules.to_openmath(expression)
        @test object.applicant == symbol
        @test isequal(OpenSymbolicRules.from_openmath(object), expression)
    end
end

end # OpenMath is an opt-in test dependency.
