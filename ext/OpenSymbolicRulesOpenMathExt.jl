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
    :Limit => OpenMath.OMSymbol("limit1", "limit"),
    :BothSides => OpenMath.OMSymbol("limit1", "both_sides"),
)

const _OPENMATH_TO_OSR = Dict{Tuple{String, String}, Any}(
    (symbol.cd, symbol.name) => getfield(OpenSymbolicRules, head)
    for (head, symbol) in _OSR_TO_OPENMATH
)

_symbol_key(symbol::OpenMath.OMSymbol) = (symbol.cd, symbol.name)
_to_openmath(value) = value isa SymbolicUtils.BasicSymbolic ?
    OpenSymbolicRules.to_openmath(value) : OpenMath.to_openmath(value)

"""Export an OSR collection with the OpenMath `list1#list` semantics."""
OpenSymbolicRules.to_openmath(values::AbstractVector) =
    OpenMath.OMSymbol("list1", "list")((_to_openmath(value) for value in values)...)

function OpenSymbolicRules.to_openmath(value::Irrational)
    value === π && return OpenMath.OMSymbol("nums1", "pi")
    value === ℯ && return OpenMath.OMSymbol("nums1", "e")
    throw(OpenMath.OpenMathConversionError(typeof(value),
        "no OpenMath Content Dictionary symbol is registered for this irrational constant"))
end

function OpenSymbolicRules.to_openmath(value::Complex)
    value === im && return OpenMath.OMSymbol("complex1", "i")
    return OpenMath.to_openmath(value)
end

function _bound_variable(value)
    value = OpenSymbolicRules._literal(value)
    if value isa SymbolicUtils.BasicSymbolic && !SymbolicUtils.iscall(value)
        return OpenMath.OMBoundVariable(String(SymbolicUtils.getname(value)))
    elseif value isa Symbol
        return OpenMath.OMBoundVariable(String(value))
    elseif value isa AbstractString
        return OpenMath.OMBoundVariable(value)
    end
    throw(ArgumentError("an OSR Lambda variable must be a bare symbolic variable"))
end

function _piecewise_part(branch)
    branch = OpenSymbolicRules._literal(branch)
    SymbolicUtils.iscall(branch) || throw(ArgumentError(
        "an OSR Piecewise branch must be Piece(value, condition) or Otherwise(value)"))
    head = Symbol(nameof(SymbolicUtils.operation(branch)))
    arguments = SymbolicUtils.arguments(branch)
    if head === :Piece && length(arguments) == 2
        return OpenMath.OMSymbol("piece1", "piece")(
            _to_openmath(arguments[1]), _to_openmath(arguments[2]))
    elseif head === :Otherwise && length(arguments) == 1
        return OpenMath.OMSymbol("piece1", "otherwise")(_to_openmath(only(arguments)))
    end
    throw(ArgumentError(
        "an OSR Piecewise branch must be Piece(value, condition) or Otherwise(value)"))
end

function OpenSymbolicRules.to_openmath(expr::SymbolicUtils.BasicSymbolic)
    literal = OpenSymbolicRules._literal(expr)
    literal !== expr && return _to_openmath(literal)

    if SymbolicUtils.iscall(expr)
        head = Symbol(nameof(SymbolicUtils.operation(expr)))
        arguments = SymbolicUtils.arguments(expr)
        if head === :Lambda
            length(arguments) == 2 || throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OSR Lambda requires a variable and a body"))
            return OpenMath.OMBinding(OpenMath.OMSymbol("fns1", "lambda"),
                [_bound_variable(arguments[1])], _to_openmath(arguments[2]))
        elseif head === :Derivative
            length(arguments) == 1 || throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OpenMath calculus1#diff requires Derivative(Lambda(variable, body))"))
            lambda = only(arguments)
            SymbolicUtils.iscall(lambda) &&
                Symbol(nameof(SymbolicUtils.operation(lambda))) === :Lambda ||
                throw(OpenMath.OpenMathConversionError(typeof(expr),
                    "OpenMath calculus1#diff requires Derivative(Lambda(variable, body))"))
            return OpenMath.OMSymbol("calculus1", "diff")(_to_openmath(lambda))
        elseif head === :Piecewise
            length(arguments) == 1 || throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OSR Piecewise requires exactly one branch collection"))
            branches = OpenSymbolicRules.osr_collection(only(arguments))
            branches === nothing && throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OSR Piecewise requires a branch collection"))
            isempty(branches) && throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OSR Piecewise requires at least one branch"))
            return OpenMath.OMSymbol("piece1", "piecewise")(
                (_piecewise_part(branch) for branch in branches)...)
        end
        if head === :Sqrt
            length(arguments) == 1 || throw(OpenMath.OpenMathConversionError(
                typeof(expr), "OSR Sqrt requires exactly one argument"))
            return OpenMath.OMSymbol("arith1", "root")(
                _to_openmath(only(arguments)), OpenMath.OMInteger(2))
        end
        symbol = get(_OSR_TO_OPENMATH, head, nothing)
        symbol === nothing && throw(OpenMath.OpenMathConversionError(
            typeof(expr), "no OpenMath symbol is registered for OSR head `$(head)`"))
        return symbol((_to_openmath(argument)
            for argument in SymbolicUtils.arguments(expr))...)
    end

    name = SymbolicUtils.getname(expr)
    name === :BothSides && return _OSR_TO_OPENMATH[:BothSides]
    return OpenMath.OMVariable(String(name))
end

OpenSymbolicRules.from_openmath(object::OpenMath.OMInteger) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMFloat) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMString) = object.value
OpenSymbolicRules.from_openmath(object::OpenMath.OMVariable) =
    SymbolicUtils.Sym{SymbolicUtils.SymReal}(Symbol(object.name); type=Real)

function OpenSymbolicRules.from_openmath(object::OpenMath.OMBinding)
    binder = object.binder
    binder isa OpenMath.OMSymbol && _symbol_key(binder) == ("fns1", "lambda") ||
        throw(ArgumentError("only OpenMath fns1#lambda bindings map to OSR Lambda"))
    length(object.variables) == 1 || throw(ArgumentError(
        "OSR Lambda currently requires exactly one bound variable"))
    variable = OpenSymbolicRules.from_openmath(
        OpenMath.OMVariable(only(object.variables).name))
    return OpenSymbolicRules.Lambda(variable,
        OpenSymbolicRules.from_openmath(object.body))
end

function OpenSymbolicRules.from_openmath(object::OpenMath.OMSymbol)
    key = _symbol_key(object)
    key == ("logic1", "true") && return true
    key == ("logic1", "false") && return false
    key == ("limit1", "both_sides") && return OpenSymbolicRules.BothSides
    key == ("nums1", "pi") && return π
    key == ("nums1", "e") && return ℯ
    key == ("complex1", "i") && return im
    throw(ArgumentError("OpenMath symbol `$(object.cd)#$(object.name)` is not an OSR expression"))
end

function _from_piecewise_part(object::OpenMath.OMNode)
    object isa OpenMath.OMApplication || throw(ArgumentError(
        "OpenMath piece1#piecewise arguments must be applications"))
    applicant = object.applicant
    applicant isa OpenMath.OMSymbol || throw(ArgumentError(
        "OpenMath piece1#piecewise arguments require symbol applicants"))
    key = _symbol_key(applicant)
    if key == ("piece1", "piece") && length(object.arguments) == 2
        return OpenSymbolicRules.Piece(
            OpenSymbolicRules.from_openmath(object.arguments[1]),
            OpenSymbolicRules.from_openmath(object.arguments[2]))
    elseif key == ("piece1", "otherwise") && length(object.arguments) == 1
        return OpenSymbolicRules.Otherwise(
            OpenSymbolicRules.from_openmath(only(object.arguments)))
    end
    throw(ArgumentError("invalid OpenMath piece1#piecewise branch"))
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

    key == ("list1", "list") && return [
        OpenSymbolicRules.from_openmath(argument) for argument in object.arguments
    ]

    if key == ("arith1", "root")
        length(object.arguments) == 2 || throw(ArgumentError(
            "OpenMath arith1#root requires exactly two arguments"))
        degree = OpenSymbolicRules.from_openmath(object.arguments[2])
        degree == 2 || throw(ArgumentError(
            "only OpenMath arith1#root with degree 2 maps to OSR Sqrt"))
        return OpenSymbolicRules.Sqrt(
            OpenSymbolicRules.from_openmath(object.arguments[1]))
    end

    if key == ("calculus1", "diff")
        length(object.arguments) == 1 || throw(ArgumentError(
            "OpenMath calculus1#diff requires exactly one lambda argument"))
        lambda = OpenSymbolicRules.from_openmath(only(object.arguments))
        SymbolicUtils.iscall(lambda) &&
            Symbol(nameof(SymbolicUtils.operation(lambda))) === :Lambda ||
            throw(ArgumentError("OpenMath calculus1#diff requires an fns1#lambda binding"))
        return OpenSymbolicRules.Derivative(lambda)
    end

    if key == ("piece1", "piecewise")
        isempty(object.arguments) && throw(ArgumentError(
            "OpenMath piece1#piecewise requires at least one branch"))
        branches = [_from_piecewise_part(part) for part in object.arguments]
        SymbolicUtils.iscall(last(branches)) &&
            Symbol(nameof(SymbolicUtils.operation(last(branches)))) === :Otherwise ||
            throw(ArgumentError("OpenMath piece1#piecewise requires a final piece1#otherwise"))
        return OpenSymbolicRules.Piecewise(branches)
    end

    head = get(_OPENMATH_TO_OSR, key, nothing)
    head === nothing && throw(ArgumentError(
        "OpenMath symbol `$(applicant.cd)#$(applicant.name)` has no OSR head"))
    return head((OpenSymbolicRules.from_openmath(argument)
        for argument in object.arguments)...)
end

end
