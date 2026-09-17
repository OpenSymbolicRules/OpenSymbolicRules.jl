using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments

"""
    OSRPiece(value, condition)

One branch of a `Piecewise` expression.  A final `Otherwise` branch has
no condition of its own, so its `condition` is `nothing`.
"""
struct OSRPiece
    value::Any
    condition::Any
end

"""
    piecewise_pieces(expr)

Return the branches of a `Piecewise` expression in declaration order, or
`nothing` when `expr` is not a piecewise.
"""
function piecewise_pieces(expr)
    _has_head(expr, :Piecewise) || return nothing
    operands = arguments(_literal(expr))
    length(operands) == 1 || return nothing
    branches = osr_collection(only(operands))
    branches === nothing && return nothing

    pieces = OSRPiece[]
    for branch in branches
        branch = _literal(branch)
        if _has_head(branch, :Piece)
            parts = arguments(branch)
            length(parts) == 2 || return nothing
            push!(pieces, OSRPiece(parts[1], parts[2]))
        elseif _has_head(branch, :Otherwise)
            parts = arguments(branch)
            length(parts) == 1 || return nothing
            push!(pieces, OSRPiece(only(parts), nothing))
        else
            return nothing
        end
    end
    return pieces
end

"""
    _NUMERIC_CONDITIONS

Predicate deciding a relation head, used only when every operand is a closed
arithmetic expression.  For a symbolic operand these predicates answer "not
proved", which is not the same as "false", so they may not decide a condition.
"""
const _NUMERIC_CONDITIONS = Dict{Symbol,Function}(
    :GreaterThan => GtQ,
    :LessThan => LtQ,
    :IsPositive => is_positive,
    :IsNegative => is_negative,
    :IsNonzero => is_nonzero,
    :IsInteger => IntegerQ,
)

"""
    decide_condition(condition)

Decide a `Piecewise` condition, returning `true`, `false`, or `nothing` when it
is undecided.

A condition is decided when it is a Boolean literal, when it is a relation over
closed arithmetic expressions, or when it — or its negation — is an active
hypothesis.  `And`, `Or`, and `Not` combine those answers with three-valued
logic, so a conjunction with one false operand is false even when the other is
unknown.
"""
function decide_condition(condition)
    condition = _literal(condition)
    condition isa Bool && return condition

    if iscall(condition)
        name = _operation_name(operation(condition))
        operands = arguments(condition)

        if name === :Not && length(operands) == 1
            inner = decide_condition(only(operands))
            return inner === nothing ? nothing : !inner
        elseif name === :And
            decided = map(decide_condition, operands)
            any(value -> value === false, decided) && return false
            all(value -> value === true, decided) && return true
            return nothing
        elseif name === :Or
            decided = map(decide_condition, operands)
            any(value -> value === true, decided) && return true
            all(value -> value === false, decided) && return false
            return nothing
        end

        predicate = name === nothing ? nothing : get(_NUMERIC_CONDITIONS, name, nothing)
        if predicate !== nothing && all(operand -> osr_number(operand) !== nothing, operands)
            return predicate(operands...)
        end
    end

    check_assumption(condition) && return true
    return nothing
end

"""
    select_piece(expr)

Reduce a `Piecewise` expression to the value of the branch that applies, or
return it unchanged when the applicable branch is not settled.

Branches are examined in order.  A branch is taken once its condition is decided
true and every earlier condition is decided false; an undecided condition stops
the search, because a later branch may not overtake one that might yet apply.
"""
function select_piece(expr)
    pieces = piecewise_pieces(expr)
    pieces === nothing && return expr

    for piece in pieces
        piece.condition === nothing && return piece.value
        decided = decide_condition(piece.condition)
        decided === nothing && return expr
        decided && return piece.value
    end
    return expr
end

export OSRPiece, piecewise_pieces, decide_condition, select_piece
