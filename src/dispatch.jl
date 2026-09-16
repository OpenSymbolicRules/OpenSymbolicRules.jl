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

function _has_optional_slot(pattern)
    _literal(pattern) isa SymbolicUtils.DefSlot && return true
    iscall(pattern) || return false
    _has_optional_slot(operation(pattern)) && return true
    return any(_has_optional_slot, arguments(pattern))
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

    for (index, rule) in enumerate(rules)
        head = rule_head(rule)
        if head === nothing
            push!(unindexed, index)
        else
            push!(get!(Vector{Int}, positions, head), index)
        end
    end

    # A rule that may match any head belongs to every group, and each group stays
    # in the original rule order.
    if !isempty(unindexed)
        for group in values(positions)
            append!(group, unindexed)
            sort!(group)
        end
    end

    return OSRDispatch(rules, positions, unindexed)
end

"""
    candidate_positions(dispatch, expr)

Return the positions, in the original rule order, of the rules that can match
`expr`.
"""
function candidate_positions(dispatch::OSRDispatch, expr)
    iscall(expr) || return dispatch.unindexed
    return get(dispatch.positions, operation(expr), dispatch.unindexed)
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
