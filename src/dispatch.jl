using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments
using SymbolicUtils.Rewriters

"""
    rule_head(rule)

Return the operation a rule's pattern requires at the root of a term, or
`nothing` when the rule may match a term of any head.

A rewrite whose pattern is headed by a concrete operation cannot match a term
with a different one, so its matcher never has to run.  Three kinds of pattern
have no such requirement and must always be tried: a bare slot, a slot in head
position, and a pattern containing an optional slot, which `SymbolicUtils` lets
match a term that lacks the operation entirely.
"""
rule_head(rule::OSRRule) = rule_head(rule.rule)
rule_head(rule::SymbolicUtils.ACRule) = rule_head(SymbolicUtils.Rule(rule))

function rule_head(rule::SymbolicUtils.Rule)
    pattern = rule.lhs
    iscall(pattern) || return nothing
    _has_optional_slot(pattern) && return nothing
    head = operation(pattern)
    _is_pattern_variable(head) && return nothing
    return head
end

rule_head(::Any) = nothing

function _is_pattern_variable(value)
    # A pattern variable is stored as a symbolic literal inside the pattern.
    value = _literal(value)
    return value isa SymbolicUtils.Slot || value isa SymbolicUtils.Segment ||
           value isa SymbolicUtils.DefSlot
end

"""
    _has_optional_slot(pattern)

Return whether `pattern` may match a term that lacks its own operation.

`SymbolicUtils` builds a default-valued matcher only where a `DefSlot` is a
*direct* argument: such a term also matches its remaining operand alone, so it
requires no particular head. An optional operand nested deeper does not relax
the root — `Int((a. + b.*x)^m., x)` still needs an `Int` — which is what keeps
head dispatch selective across a rule set as large as RUBI's.
"""
function _has_optional_slot(pattern)
    _literal(pattern) isa SymbolicUtils.DefSlot && return true
    iscall(pattern) || return false
    return any(argument -> _literal(argument) isa SymbolicUtils.DefSlot,
               arguments(pattern))
end

"""
    dispatch_key(rule)

Return the pair of operations a term must have at its root and at its first
operand for `rule` to have any chance of matching, with `nothing` in either
position that the pattern leaves open.

The root head alone stops discriminating as soon as a rule set is about one
operation: every RUBI integration rule is headed by `Int`, so indexing on the
root selects the whole set for every integral. What distinguishes those rules is
the integrand, which is the first operand.
"""
function dispatch_key(rule)
    head = rule_head(rule)
    head === nothing && return nothing
    return (head, _operand_head(rule))
end

"""
    _operand_head(rule)

Return the operation `rule` requires at the first operand of its pattern, or
`nothing` when it requires none.

An associative-commutative rule requires none: its matcher tries every operand
order, so the operation at the term's first operand does not decide whether the
rule can match.
"""
_operand_head(rule::OSRRule) = _operand_head(rule.rule)

# An associative-commutative rule matches its operands in any order, so which
# operation sits first in the term says nothing about whether it can match.
_operand_head(::SymbolicUtils.ACRule) = nothing

function _operand_head(rule::SymbolicUtils.Rule)
    pattern = rule.lhs
    iscall(pattern) || return nothing
    operands = arguments(pattern)
    isempty(operands) && return nothing
    operand = operands[1]
    _is_pattern_variable(_literal(operand)) && return nothing
    iscall(operand) || return nothing
    _has_optional_slot(operand) && return nothing
    head = operation(operand)
    _is_pattern_variable(head) && return nothing
    return head
end

_operand_head(::Any) = nothing

"""
    _term_key(expr)

Return the pair of operations `expr` actually has at its root and first operand.
"""
function _term_key(expr)
    iscall(expr) || return nothing
    operands = arguments(expr)
    head = operation(expr)
    isempty(operands) && return (head, nothing)
    operand = operands[1]
    return (head, iscall(operand) ? operation(operand) : nothing)
end

"""
    OSRDispatch(rules)

A rewriter that applies `rules` to a term the way `SymbolicUtils.Rewriters.Chain`
does — each rule in turn, threading the result — while skipping the rules whose
pattern is headed by a different operation.

Selecting candidates costs one dictionary lookup instead of one matcher call per
rule, which is what keeps a large rule set, such as the 6000 RUBI integration
rules, usable.
"""
struct OSRDispatch{R}
    rules::R
    positions::Dict{Any,Vector{Int}}
    unindexed::Vector{Int}
end

function OSRDispatch(rules)
    positions = Dict{Any,Vector{Int}}()
    unindexed = Int[]
    # Rules that fix a root head but leave the first operand open: candidates
    # for every term with that root, whatever its operand.
    open_operand = Dict{Any,Vector{Int}}()

    for (index, rule) in enumerate(rules)
        key = dispatch_key(rule)
        if key === nothing
            push!(unindexed, index)
        elseif key[2] === nothing
            push!(get!(Vector{Int}, open_operand, key[1]), index)
        else
            push!(get!(Vector{Int}, positions, key), index)
        end
    end

    # A rule that leaves a position open belongs to every group it subsumes, and
    # each group stays in the original rule order.
    for (key, group) in positions
        append!(group, get(open_operand, key[1], Int[]))
        append!(group, unindexed)
        sort!(group)
    end
    for (head, group) in open_operand
        append!(group, unindexed)
        sort!(group)
        # A term whose first operand heads no rule still reaches these.
        positions[(head, nothing)] = group
    end
    if !isempty(unindexed)
        sort!(unindexed)
    end

    return OSRDispatch(rules, positions, unindexed)
end

"""
    candidate_positions(dispatch, expr)

Return the positions, in the original rule order, of the rules that can match
`expr`.
"""
function candidate_positions(dispatch::OSRDispatch, expr)
    key = _term_key(expr)
    key === nothing && return dispatch.unindexed
    group = get(dispatch.positions, key, nothing)
    group === nothing || return group
    # No rule fixes this operand head, so only those leaving it open apply.
    return get(dispatch.positions, (key[1], nothing), dispatch.unindexed)
end

function (dispatch::OSRDispatch)(expr)
    current = expr
    cursor = 0
    while true
        positions = candidate_positions(dispatch, current)
        # A rewrite may change the head, so the candidates are re-selected; the
        # cursor keeps the traversal moving forward through the original order.
        next = searchsortedfirst(positions, cursor + 1)
        next > length(positions) && return current
        cursor = positions[next]
        result = dispatch.rules[cursor](current)
        result === nothing || (current = result)
    end
end

Rewriters.instrument(dispatch::OSRDispatch, f) =
    OSRDispatch(map(rule -> Rewriters.instrument(rule, f), dispatch.rules),
                dispatch.positions, dispatch.unindexed)

export OSRDispatch
