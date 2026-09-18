using TestItems

@testitem "OpenMath extension exports and imports core symbolic expressions" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    object = OpenMath.to_openmath(Add(x, 1))

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
    object = OpenMath.to_openmath(Power(x, 3 // 2))

    @test object.applicant == OpenMath.OMSymbol("arith1", "power")
    @test object.arguments[2].applicant == OpenMath.OMSymbol("nums1", "rational")
    @test OpenSymbolicRules.from_openmath(object) |> SymbolicUtils.arguments |> last == 3 // 2
end

@testitem "OpenMath extension rejects heads without an exact semantic binding" begin
    using OpenMath
    using OpenSymbolicRules
    using SymbolicUtils

    @syms x
    @test_throws OpenMath.OpenMathConversionError OpenMath.to_openmath(Sqrt(x))
end
