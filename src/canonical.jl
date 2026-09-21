using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments

"""
    canonical(expression)

Return a deterministic normal form of `expression`.

Normalizing is not evaluating. It folds what is already closed, drops what does
nothing, and fixes an order where one is sound; it never decides anything the
expression left open, and a head this package does not evaluate keeps its place
with its operands normalized.

What it does:

  * evaluates a closed arithmetic subterm exactly, so `x^(3 - 1)` becomes `x^2`
    and a correct answer stops reading as a wrong one;
  * writes a rational whose denominator is one as that integer;
  * drops an identity operand — `x + 0`, `x * 1`, `x^1` — which is sound for
    every additive group and every multiplicative monoid, matrices included;
  * orders the summands of a sum, addition being commutative wherever it is
    defined.

What it deliberately does not do:

  * reorder the factors of a product. An OSR expression carries no shape
    information, so a factor may be a matrix or a tensor and the order is part
    of the meaning;
  * turn `x^0` into `1`, which holds only where `x` is nonzero;
  * change precedence, associativity, or the domain of anything.

`canonical` is idempotent.
"""
function canonical(expression)
    literal = _literal(expression)
    value = osr_number(literal)
    value === nothing || return _canonical_number(value)
    iscall(literal) || return expression

    head = operation(literal)
    operands = [canonical(operand) for operand in arguments(literal)]
    name = _operation_name(head)

    if name === :Add
        operands = _drop_identity(operands, 0)
        isempty(operands) && return 0
        length(operands) == 1 && return only(operands)
        # Addition commutes wherever it is defined, so a fixed order is sound
        # and is what lets two answers be compared.
        sort!(operands; by = _canonical_key)
    elseif name === :Multiply
        operands = _drop_identity(operands, 1)
        isempty(operands) && return 1
        length(operands) == 1 && return only(operands)
        # The factor order is left alone: see the docstring.
    elseif name === :Power && length(operands) == 2
        exponent = osr_number(operands[2])
        exponent !== nothing && exponent == 1 && return operands[1]
    end

    all(isequal.(operands, arguments(literal))) && return expression
    return head(operands...)
end

"""
    canonically_equal(left, right)

Return whether two expressions have the same normal form.

This is a structural test after normalization, not a proof of mathematical
equality: two expressions that differ only in what [`canonical`](@ref)
deliberately leaves alone still compare unequal.
"""
canonically_equal(left, right) = isequal(canonical(left), canonical(right))

"""
    _canonical_number(value)

Write an exact number in its settled form: a rational whose denominator is one
is that integer.
"""
function _canonical_number(value)
    value isa Rational && denominator(value) == 1 && return numerator(value)
    return value
end

"""
    _drop_identity(operands, identity)

Return the operands that are not the identity element of their operation.
"""
function _drop_identity(operands, identity)
    return filter(operands) do operand
        value = osr_number(operand)
        value === nothing || value != identity
    end
end

"""
    _canonical_key(operand)

A deterministic sort key for the summands of a sum.  It orders by printed form,
which settles a sum's shape without claiming any mathematical meaning for the
order itself.
"""
_canonical_key(operand) = string(operand)

export canonical, canonically_equal
