using SymbolicUtils
using DomainSets
using IntervalSets

"""
    _PROPERTIES

The properties a hypothesis can establish about a term.  `check_assumption`
answers each one by entailment, so a hypothesis proves every property its domain
implies rather than only the one it was written as.
"""
const _PROPERTIES = (:positive, :negative, :nonzero, :integer, :real, :complex)

"""
    _type_entails(type, property)

Entailment of a hypothesis written as a Julia type, as in `x ∈ Int`.
"""
function _type_entails(type::Type, property::Symbol)
    type <: Integer && return property in (:integer, :real, :complex)
    type <: Real && return property in (:real, :complex)
    type <: Number && return property === :complex
    return false
end

"""
    _interval_entails(domain, property)

Entailment of an ordered domain, read from its bounds.  A bound at zero only
excludes zero when it is open, so `[0, ∞)` is not a proof of positivity while
`(0, ∞)` is.
"""
function _interval_entails(domain, property::Symbol)
    lower, upper = infimum(domain), supremum(domain)
    lower isa Real && upper isa Real || return false

    property in (:real, :complex) && return true
    # An ordered domain holds more than the integers unless it is a single point.
    property === :integer && return lower == upper && isinteger(lower)

    positive = lower > 0 || (lower == 0 && isleftopen(domain))
    property === :positive && return positive
    negative = upper < 0 || (upper == 0 && isrightopen(domain))
    property === :negative && return negative
    property === :nonzero && return positive || negative
    return false
end

"""
    _domain_entails(domain, property)

Return whether membership of `domain` proves `property`.
"""
function _domain_entails(domain, property::Symbol)
    domain isa Type && return _type_entails(domain, property)
    domain isa DomainSets.Integers && return property in (:integer, :real, :complex)
    domain isa DomainSets.RealNumbers && return property in (:real, :complex)
    domain isa DomainSets.ComplexNumbers && return property === :complex
    applicable(infimum, domain) && applicable(supremum, domain) || return false
    return _interval_entails(domain, property)
end

"""
    _relation_entails(head, operands, property)

Entailment of a hypothesis written as a relation, such as `GreaterThan(x, 0)`.
A comparison also orders its subject, so it proves that the subject is real.
"""
function _relation_entails(head::Symbol, operands, property::Symbol)
    if head === :IsPositive
        return property in (:positive, :nonzero, :real, :complex)
    elseif head === :IsNegative
        return property in (:negative, :nonzero, :real, :complex)
    elseif head === :IsNonzero
        return property === :nonzero
    elseif head === :IsInteger
        return property in (:integer, :real, :complex)
    elseif head === :GreaterThan || head === :LessThan
        length(operands) == 2 || return false
        bound = osr_number(operands[2])
        bound isa Real || return false
        property in (:real, :complex) && return true
        if head === :GreaterThan
            bound >= 0 && return property in (:positive, :nonzero)
        else
            bound <= 0 && return property in (:negative, :nonzero)
        end
    end
    return false
end

"""
    normalize_fact(fact)

Return the OSR facts a hypothesis stands for.

A host may spell a membership hypothesis in its own type — `Symbolics.jl` builds
a `VarDomainPairing` for `x ∈ 2..5` once it is loaded — so a hypothesis is
normalised to [`ElementOf`](@ref) when it enters the context, and the entailment
rules then only ever see OSR facts.
"""
normalize_fact(fact) = Any[fact]

_normalize_facts(facts) = collect(Iterators.flatten(normalize_fact(fact) for fact in facts))

"""
    _fact_entails(fact, subject, property)

Return whether one hypothesis proves `property` of `subject`.
"""
function _fact_entails(fact, subject, property::Symbol)
    if fact isa ElementOf
        isequal(fact.var, subject) || return false
        return _domain_entails(fact.domain, property)
    end

    fact = _literal(fact)
    iscall(fact) || return false
    head = _operation_name(operation(fact))
    head === nothing && return false
    operands = arguments(fact)
    isempty(operands) && return false
    isequal(_literal(operands[1]), _literal(subject)) || return false
    return _relation_entails(head, operands, property)
end

"""
    entailed(subject, property)

Return whether the hypotheses in scope prove `property` of `subject`.

Each hypothesis is asked on its own, so the answer is sound but does not combine
two hypotheses into a third: `x ∈ ℤ` proves integrality and `x > 0` proves
positivity, yet neither alone proves that `x` is a positive integer.
"""
function entailed(subject, property::Symbol)
    context = get(task_local_storage(), :osr_assumptions, nothing)
    context === nothing && return false
    for fact in context
        _fact_entails(fact, subject, property) && return true
    end
    return false
end

function _rational_assumption_variable(expression)
    expression = _literal(expression)
    iscall(expression) && return nothing
    try
        SymbolicUtils.getname(expression)
    catch error
        error isa ErrorException || rethrow()
        nothing
    end
end

function _rational_assumption_constraint(fact)
    fact = _literal(fact)
    iscall(fact) || return nothing
    head = _operation_name(operation(fact))
    operands = arguments(fact)
    isempty(operands) && return nothing
    variable = _rational_assumption_variable(operands[1])
    variable isa Symbol || return nothing

    if head === :IsPositive
        length(operands) == 1 || return nothing
        return LinearConstraint(Dict(variable => -1), :lt, 0)
    elseif head === :IsNegative
        length(operands) == 1 || return nothing
        return LinearConstraint(Dict(variable => 1), :lt, 0)
    elseif head === :GreaterThan || head === :LessThan
        length(operands) == 2 || return nothing
        bound = osr_number(operands[2])
        _is_rational(bound) || return nothing
        if head === :GreaterThan
            return LinearConstraint(Dict(variable => -1), :lt, -bound)
        end
        return LinearConstraint(Dict(variable => 1), :lt, bound)
    end
    nothing
end

"""
    rational_assumptions_satisfiable(facts) -> Union{Bool, Nothing}

Check a supported collection of CAS hypotheses with the exact rational linear
theory. `true` means the converted hypotheses have a rational model, `false`
means they are contradictory, and `nothing` means at least one hypothesis is
outside this deliberately conservative fragment. Supported facts are
`IsPositive(x)`, `IsNegative(x)`, `GreaterThan(x, c)`, and `LessThan(x, c)`
for a named symbolic variable `x` and an exact rational constant `c`.
"""
function rational_assumptions_satisfiable(facts)
    constraints = LinearConstraint[]
    for fact in _normalize_facts(facts)
        constraint = _rational_assumption_constraint(fact)
        constraint === nothing && return nothing
        push!(constraints, constraint)
    end
    linear_satisfiable(constraints)
end

export entailed, normalize_fact, rational_assumptions_satisfiable
