module OpenSymbolicRulesOpenMathExt

using OpenMath
using OpenSymbolicRules
using SymbolicUtils

const _OSR_TO_OPENMATH = Dict{Symbol, OpenMath.OMSymbol}(
    :Add => OpenMath.OMSymbol("arith1", "plus"),
    :Multiply => OpenMath.OMSymbol("arith1", "times"),
    :Power => OpenMath.OMSymbol("arith1", "power"),
    :Divide => OpenMath.OMSymbol("arith1", "divide"),
    :Subtract => OpenMath.OMSymbol("arith1", "minus"),
    :Sin => OpenMath.OMSymbol("transc1", "sin"),
    :Cos => OpenMath.OMSymbol("transc1", "cos"),
    :Tan => OpenMath.OMSymbol("transc1", "tan"),
    :Exp => OpenMath.OMSymbol("transc1", "exp"),
    :Log => OpenMath.OMSymbol("transc1", "ln"),
    :And => OpenMath.OMSymbol("logic1", "and"),
    :Or => OpenMath.OMSymbol("logic1", "or"),
    :Not => OpenMath.OMSymbol("logic1", "not"),
    :Implies => OpenMath.OMSymbol("logic1", "implies"),
    :Equivalent => OpenMath.OMSymbol("logic1", "equivalent"),
    :Nand => OpenMath.OMSymbol("logic1", "nand"),
    :Nor => OpenMath.OMSymbol("logic1", "nor"),
    :Xor => OpenMath.OMSymbol("logic1", "xor"),
)

const _OPENMATH_TO_OSR = Dict{Tuple{String, String}, Any}(
    (symbol.cd, symbol.name) => getfield(OpenSymbolicRules, head)
    for (head, symbol) in _OSR_TO_OPENMATH
)

_symbol_key(symbol::OpenMath.OMSymbol) = (symbol.cd, symbol.name)

function OpenMath.to_openmath(expr::SymbolicUtils.BasicSymbolic)
    literal = OpenSymbolicRules._literal(expr)
    literal !== expr && return OpenMath.to_openmath(literal)

    if SymbolicUtils.iscall(expr)
        head = Symbol(nameof(SymbolicUtils.operation(expr)))
        symbol = get(_OSR_TO_OPENMATH, head, nothing)
        symbol === nothing && throw(OpenMath.OpenMathConversionError(
            typeof(expr), "no OpenMath symbol is registered for OSR head `$(head)`"))
        return symbol((OpenMath.to_openmath(argument)
            for argument in SymbolicUtils.arguments(expr))...)
    end

    return OpenMath.OMVariable(String(SymbolicUtils.getname(expr)))
end

OpenSymbolicRules.from_openmath(object::OpenMath.OMInteger) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMFloat) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMString) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMVariable) =
    SymbolicUtils.Sym{SymbolicUtils.SymReal}(Symbol(object.name); type=Real)

function OpenSymbolicRules.from_openmath(object::OpenMath.OMSymbol)
    key = _symbol_key(object)
    key == ("logic1", "true") && return true
    key == ("logic1", "false") && return false
    throw(ArgumentError("OpenMath symbol `$(object.cd)#$(object.name)` is not an OSR expression"))
end

function OpenSymbolicRules.from_openmath(object::OpenMath.OMApplication)
    applicant = object.applicant
    applicant isa OpenMath.OMSymbol || throw(ArgumentError(
        "an OSR expression requires an OpenMath symbol as its applicant"))
    key = _symbol_key(applicant)

    if key == ("nums1", "rational")
        length(object.arguments) == 2 || throw(ArgumentError(
            "OpenMath nums1#rational requires exactly two arguments"))
        numerator = OpenSymbolicRules.from_openmath(object.arguments[1])
        denominator = OpenSymbolicRules.from_openmath(object.arguments[2])
        numerator isa Integer && denominator isa Integer || throw(ArgumentError(
            "OpenMath nums1#rational requires integer arguments"))
        return numerator // denominator
    end

    head = get(_OPENMATH_TO_OSR, key, nothing)
    head === nothing && throw(ArgumentError(
        "OpenMath symbol `$(applicant.cd)#$(applicant.name)` has no OSR head"))
    return head((OpenSymbolicRules.from_openmath(argument)
        for argument in object.arguments)...)
end

end
