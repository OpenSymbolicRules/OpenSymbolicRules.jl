using TestItems

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
