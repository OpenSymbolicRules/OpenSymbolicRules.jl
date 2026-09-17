using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments, isconst, unwrap_const

"""
    _literal(expr)

Unwrap a symbolic numeric literal.  `SymbolicUtils` wraps the arguments of a
term, so `arguments(Add(1, 2))` yields symbolic constants rather than `Int`s.
"""
_literal(expr) = expr isa SymbolicUtils.BasicSymbolic && isconst(expr) ? unwrap_const(expr) : expr

# ---------------------------------------------------------------------------
# Numeric evaluation of closed OSR arithmetic expressions
# ---------------------------------------------------------------------------

"""
    _CANONICAL_ARITHMETIC

Julia operation behind every canonical OSR arithmetic head.  A rule file that
renames those heads keeps working, but its expressions are then opaque to
numeric folding and every guarded rewrite stays conservative.
"""
const _CANONICAL_ARITHMETIC = Dict{Symbol,Function}(
    :Add => +,
    :Multiply => *,
    :Subtract => -,
    :Divide => /,
    :Power => ^,
)

_operation_name(op) = op isa SymbolicUtils.BasicSymbolic ? nameof(op) : nothing

function _numeric_operation(op)
    # A symbolic head is itself callable, so it must be recognised by name
    # before the plain Julia operations are considered.
    name = _operation_name(op)
    name === nothing || return get(_CANONICAL_ARITHMETIC, name, nothing)
    op isa Function || return nothing
    return any(candidate -> op === candidate, (+, -, *, /, ^)) ? op : nothing
end

"""
    _exact_power(base, exponent)

Raise `base` to `exponent` without losing exactness.  Julia refuses to raise an
integer to a negative integer power, yet `Power(u, -1)` is how OSR spells a
reciprocal, so the base is widened to a rational first.
"""
function _exact_power(base::Number, exponent::Number)
    if base isa Integer && exponent isa Integer && exponent < 0
        return Rational(base)^exponent
    end
    return base^exponent
end

"""
    osr_number(expr)

Return the exact numeric value of a closed OSR arithmetic expression, or
`nothing` when `expr` still contains a symbol, uses a head with no arithmetic
meaning, or does not denote a number at all.

```jldoctest
julia> using OpenSymbolicRules

julia> OpenSymbolicRules.osr_number(Power(2, -1))
1//2

julia> OpenSymbolicRules.osr_number(Add(1, 2))
3
```
"""
function osr_number(expr)
    expr = _literal(expr)
    expr isa Number && return expr
    iscall(expr) || return nothing
    operation_function = _numeric_operation(operation(expr))
    operation_function === nothing && return nothing
    operation_function = operation_function === (^) ? _exact_power : operation_function

    values = Any[]
    for argument in arguments(expr)
        value = osr_number(argument)
        value === nothing && return nothing
        push!(values, value)
    end

    value = try
        operation_function(values...)
    catch error
        error isa Union{DomainError,DivideError,OverflowError,InexactError} || rethrow()
        return nothing
    end
    value isa Number && isfinite(value) || return nothing
    return value
end

_real_number(expr) = (value = osr_number(expr); value isa Real ? value : nothing)

# ---------------------------------------------------------------------------
# Comparison predicates
# ---------------------------------------------------------------------------

"""
    EqQ(u, v)

Return whether `u` and `v` are provably equal.  Two closed arithmetic
expressions are compared by value and two identical terms are equal by
construction; nothing else counts as a proof, so an unproved equality is
reported as `false` and the guarded rewrite is skipped.
"""
function EqQ(u, v)
    left, right = osr_number(u), osr_number(v)
    left !== nothing && right !== nothing && return left == right
    return isequal(_literal(u), _literal(v))
end

"""
    NeQ(u, v)

Return whether `u` and `v` are provably different.  Symbolic terms are not
unequal merely because their structures differ: without a proof the predicate
returns `false` and the guarded rewrite is skipped.
"""
function NeQ(u, v)
    left, right = osr_number(u), osr_number(v)
    return left !== nothing && right !== nothing && left != right
end

function _compare(comparison, values)
    numbers = map(_real_number, values)
    any(isnothing, numbers) && return false
    for index in 1:(length(numbers) - 1)
        comparison(numbers[index], numbers[index + 1]) || return false
    end
    return true
end

"""
    GtQ(u, v)
    GtQ(u, v, w)

Return whether the real values of the arguments are strictly decreasing, so
`GtQ(u, v, w)` means `u > v > w`.  Arguments that are not closed real
expressions make the predicate `false`.
"""
GtQ(values...) = _compare(>, values)

"""
    LtQ(u, v)
    LtQ(u, v, w)

Return whether the real values of the arguments are strictly increasing.
"""
LtQ(values...) = _compare(<, values)

"""
    GeQ(u, v)
    GeQ(u, v, w)

Return whether the real values of the arguments are non-increasing.
"""
GeQ(values...) = _compare(>=, values)

"""
    LeQ(u, v)
    LeQ(u, v, w)

Return whether the real values of the arguments are non-decreasing.
"""
LeQ(values...) = _compare(<=, values)

# ---------------------------------------------------------------------------
# Numeric domain predicates
# ---------------------------------------------------------------------------

_integer_value(expr) = (value = osr_number(expr); value isa Integer ? value : nothing)

"""
    IntegerQ(u)

Return whether `u` is provably an integer, either by value or by hypothesis.
"""
IntegerQ(u) = _integer_value(u) !== nothing || is_integer(u)

"""
    IntegersQ(us...)

Return whether every argument is provably an integer.
"""
IntegersQ(values...) = all(IntegerQ, values)

"""
    IGtQ(u, n)

Return whether `u` is an integer strictly greater than `n`.
"""
IGtQ(u, n) = IntegerQ(u) && GtQ(u, n)

"""
    ILtQ(u, n)

Return whether `u` is an integer strictly less than `n`.
"""
ILtQ(u, n) = IntegerQ(u) && LtQ(u, n)

"""
    IGeQ(u, n)

Return whether `u` is an integer greater than or equal to `n`.
"""
IGeQ(u, n) = IntegerQ(u) && GeQ(u, n)

"""
    ILeQ(u, n)

Return whether `u` is an integer less than or equal to `n`.
"""
ILeQ(u, n) = IntegerQ(u) && LeQ(u, n)

_is_rational(value) = value isa Integer || value isa Rational

"""
    RationalQ(us...)

Return whether every argument is an exact rational number.  A floating-point
value is not exact and is therefore rejected.
"""
RationalQ(values...) = all(value -> _is_rational(osr_number(value)), values)

"""
    FractionQ(us...)

Return whether every argument is an exact rational number that is not an
integer.
"""
function FractionQ(values...)
    return all(values) do expression
        value = osr_number(expression)
        _is_rational(value) && !(value isa Integer)
    end
end

"""
    HalfIntegerQ(us...)

Return whether every argument is an odd multiple of one half.
"""
function HalfIntegerQ(values...)
    return all(values) do expression
        value = osr_number(expression)
        value isa Rational && denominator(value) == 2
    end
end

"""
    PosQ(u)

Return whether `u` is provably positive, either by value or by hypothesis.
"""
PosQ(u) = is_positive(something(osr_number(u), u))

"""
    NegQ(u)

Return whether `u` is provably negative, either by value or by hypothesis.
"""
NegQ(u) = is_negative(something(osr_number(u), u))

"""
    FalseQ(u)

Return whether `u` is literally the Boolean `false`.
"""
FalseQ(u) = _literal(u) === false

# ---------------------------------------------------------------------------
# Structural predicates
# ---------------------------------------------------------------------------

function _has_head(expr, head::Symbol)
    expr = _literal(expr)
    return iscall(expr) && _operation_name(operation(expr)) === head
end

"""
    AtomQ(u)

Return whether `u` has no arguments of its own.
"""
AtomQ(u) = !iscall(_literal(u))

"""
    SumQ(u)

Return whether `u` is a canonical `Add` term.
"""
SumQ(u) = _has_head(u, :Add)

"""
    ProductQ(u)

Return whether `u` is a canonical `Multiply` term.
"""
ProductQ(u) = _has_head(u, :Multiply)

"""
    PowerQ(u)

Return whether `u` is a canonical `Power` term.
"""
PowerQ(u) = _has_head(u, :Power)

"""
    osr_collection(expr)

Return the elements of a collection expression, or `nothing` when `expr` is not
one.  `SymbolicUtils` keeps a vector of plain values as a literal but wraps a
vector holding symbolic expressions in an `array_literal` term, so a collection
reaches this library in either shape.
"""
function osr_collection(expr)
    literal = _literal(expr)
    literal isa AbstractVector && return collect(literal)
    iscall(literal) || return nothing
    operation(literal) === SymbolicUtils.array_literal || return nothing
    # The first argument of an array literal is its shape.
    return collect(arguments(literal)[2:end])
end

function _elements(collection)
    _has_head(collection, :List) && return arguments(_literal(collection))
    elements = osr_collection(collection)
    return elements === nothing ? collection : elements
end

"""
    MemberQ(collection, u)

Return whether `u` occurs in `collection`, which may be a Julia collection or a
canonical `List` term.
"""
MemberQ(collection, u) = any(element -> isequal(_literal(element), _literal(u)), _elements(collection))

# ---------------------------------------------------------------------------
# Polynomial predicates
# ---------------------------------------------------------------------------

"""
    osr_degree(expr, variable)

Return the degree of `expr` as a polynomial in `variable`, or `nothing` when
`expr` is not a polynomial built from canonical arithmetic heads.  A subterm
free of `variable` is a coefficient of degree zero, whatever its own shape.
"""
function osr_degree(expr, variable)
    expr = _literal(expr)
    isequal(expr, variable) && return 1
    FreeQ(expr, variable) && return 0
    iscall(expr) || return nothing

    name = _operation_name(operation(expr))
    name === nothing && return nothing
    operands = arguments(expr)

    if name === :Add || name === :Subtract
        degree = 0
        for operand in operands
            operand_degree = osr_degree(operand, variable)
            operand_degree === nothing && return nothing
            degree = max(degree, operand_degree)
        end
        return degree
    elseif name === :Multiply
        degree = 0
        for operand in operands
            operand_degree = osr_degree(operand, variable)
            operand_degree === nothing && return nothing
            degree += operand_degree
        end
        return degree
    elseif name === :Divide
        length(operands) == 2 || return nothing
        FreeQ(operands[2], variable) || return nothing
        return osr_degree(operands[1], variable)
    elseif name === :Power
        length(operands) == 2 || return nothing
        exponent = _integer_value(operands[2])
        exponent === nothing && return nothing
        exponent < 0 && return nothing
        base_degree = osr_degree(operands[1], variable)
        base_degree === nothing && return nothing
        return base_degree * exponent
    end
    return nothing
end

"""
    PolynomialQ(u, x)

Return whether `u` is a polynomial in `x`.
"""
PolynomialQ(u, x) = osr_degree(u, x) !== nothing

"""
    PolyQ(u, x)
    PolyQ(u, x, n)

Return whether `u` is a polynomial in `x`, optionally of degree exactly `n`.
"""
PolyQ(u, x) = PolynomialQ(u, x)
PolyQ(u, x, n) = osr_degree(u, x) == _integer_value(n)

"""
    LinearQ(u, x)

Return whether `u` is a polynomial of degree one in `x`.
"""
LinearQ(u, x) = osr_degree(u, x) == 1

"""
    QuadraticQ(u, x)

Return whether `u` is a polynomial of degree two in `x`.
"""
QuadraticQ(u, x) = osr_degree(u, x) == 2

export EqQ, NeQ, GtQ, LtQ, GeQ, LeQ
export IntegerQ, IntegersQ, IGtQ, ILtQ, IGeQ, ILeQ
export RationalQ, FractionQ, HalfIntegerQ, PosQ, NegQ, FalseQ
export AtomQ, SumQ, ProductQ, PowerQ, MemberQ
export PolynomialQ, PolyQ, LinearQ, QuadraticQ, osr_degree, osr_number, osr_collection
