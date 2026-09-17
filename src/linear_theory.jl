"""Exact rational linear arithmetic for the pure-Julia SMT foundation."""

struct LinearConstraint
    coefficients::Dict{Symbol,Rational{BigInt}}
    relation::Symbol
    bound::Rational{BigInt}
end

function LinearConstraint(coefficients::AbstractDict{Symbol}, relation::Symbol, bound)
    relation in (:le, :lt, :eq) ||
        throw(ArgumentError("linear constraints support only :le, :lt, and :eq"))
    normalized = Dict{Symbol,Rational{BigInt}}()
    for (variable, coefficient) in coefficients
        value = Rational{BigInt}(coefficient)
        iszero(value) || (normalized[variable] = value)
    end
    LinearConstraint(normalized, relation, Rational{BigInt}(bound))
end

struct _LinearInequality
    coefficients::Dict{Symbol,Rational{BigInt}}
    bound::Rational{BigInt}
    strict::Bool
end

function _negated_coefficients(coefficients)
    Dict(variable => -coefficient for (variable, coefficient) in coefficients)
end

function _inequalities(constraint::LinearConstraint)
    inequality = _LinearInequality(copy(constraint.coefficients), constraint.bound,
                                   constraint.relation === :lt)
    constraint.relation === :eq || return _LinearInequality[inequality]
    return _LinearInequality[
        inequality,
        _LinearInequality(_negated_coefficients(constraint.coefficients),
                          -constraint.bound, false),
    ]
end

function _constant_satisfiable(inequality::_LinearInequality)
    isempty(inequality.coefficients) || return true
    inequality.strict ? 0 < inequality.bound : 0 <= inequality.bound
end

function _combine_for_elimination(upper::_LinearInequality, lower::_LinearInequality,
                                  variable::Symbol)
    positive = upper.coefficients[variable]
    negative = lower.coefficients[variable]
    @assert positive > 0 && negative < 0
    coefficients = Dict{Symbol,Rational{BigInt}}()
    for (name, coefficient) in upper.coefficients
        name == variable && continue
        coefficients[name] = get(coefficients, name, 0) + (-negative) * coefficient
    end
    for (name, coefficient) in lower.coefficients
        name == variable && continue
        coefficients[name] = get(coefficients, name, 0) + positive * coefficient
    end
    filter!(pair -> !iszero(last(pair)), coefficients)
    _LinearInequality(coefficients, (-negative) * upper.bound + positive * lower.bound,
                      upper.strict || lower.strict)
end

function _eliminate(inequalities::Vector{_LinearInequality}, variable::Symbol)
    positive = _LinearInequality[]
    negative = _LinearInequality[]
    remaining = _LinearInequality[]
    for inequality in inequalities
        coefficient = get(inequality.coefficients, variable, 0)
        if coefficient > 0
            push!(positive, inequality)
        elseif coefficient < 0
            push!(negative, inequality)
        else
            push!(remaining, inequality)
        end
    end
    for upper in positive, lower in negative
        push!(remaining, _combine_for_elimination(upper, lower, variable))
    end
    remaining
end

function _linear_inequalities(constraints::AbstractVector{<:LinearConstraint})
    inequalities = _LinearInequality[]
    for constraint in constraints
        append!(inequalities, _inequalities(constraint))
    end
    inequalities
end

function _linear_variables(inequalities::Vector{_LinearInequality})
    variables = Set{Symbol}()
    for inequality in inequalities
        union!(variables, keys(inequality.coefficients))
    end
    sort!(collect(variables))
end

function _tighter_lower(current, current_strict, candidate, candidate_strict)
    current === nothing && return candidate, candidate_strict
    candidate > current && return candidate, candidate_strict
    candidate == current && return current, current_strict || candidate_strict
    current, current_strict
end

function _tighter_upper(current, current_strict, candidate, candidate_strict)
    current === nothing && return candidate, candidate_strict
    candidate < current && return candidate, candidate_strict
    candidate == current && return current, current_strict || candidate_strict
    current, current_strict
end

function _choose_rational(lower, lower_strict, upper, upper_strict)
    if lower !== nothing && upper !== nothing
        lower > upper && return nothing
        lower == upper && return (lower_strict || upper_strict) ? nothing : lower
        return (lower + upper) / 2
    elseif lower !== nothing
        return lower_strict ? lower + 1 : lower
    elseif upper !== nothing
        return upper_strict ? upper - 1 : upper
    end
    zero(Rational{BigInt})
end

function _reconstruct_value(inequalities::Vector{_LinearInequality}, variable::Symbol,
                            model::Dict{Symbol,Rational{BigInt}})
    lower = upper = nothing
    lower_strict = upper_strict = false
    for inequality in inequalities
        coefficient = get(inequality.coefficients, variable, 0)
        iszero(coefficient) && continue
        remainder = sum((factor * model[name] for (name, factor) in inequality.coefficients
                         if name != variable); init=zero(Rational{BigInt}))
        bound = (inequality.bound - remainder) / coefficient
        if coefficient > 0
            upper, upper_strict = _tighter_upper(upper, upper_strict, bound, inequality.strict)
        else
            lower, lower_strict = _tighter_lower(lower, lower_strict, bound, inequality.strict)
        end
    end
    _choose_rational(lower, lower_strict, upper, upper_strict)
end

"""
    linear_satisfiable(constraints) -> Bool

Decide conjunctions of linear constraints over exact rational arithmetic using
Fourier--Motzkin elimination. A constraint represents
`Σ coefficients[variable] * variable relation bound`, where `relation` is one
of `:le`, `:lt`, or `:eq`. Strict inequalities are preserved exactly.

This is a theory solver for a future pure-Julia DPLL(T) engine; it does not use
floating point arithmetic, a native library, or an external SMT process.
"""
function linear_satisfiable(constraints::AbstractVector{<:LinearConstraint})
    inequalities = _linear_inequalities(constraints)
    all(_constant_satisfiable, inequalities) || return false

    for variable in _linear_variables(inequalities)
        inequalities = _eliminate(inequalities, variable)
        all(_constant_satisfiable, inequalities) || return false
    end
    true
end

"""
    linear_model(constraints) -> Union{Dict{Symbol,Rational{BigInt}}, Nothing}

Return an exact rational model for a satisfiable conjunction of linear
constraints, or `nothing` if it is inconsistent. The model is reconstructed
from the Fourier--Motzkin elimination layers and satisfies strict bounds
without floating point approximation.
"""
function linear_model(constraints::AbstractVector{<:LinearConstraint})
    inequalities = _linear_inequalities(constraints)
    all(_constant_satisfiable, inequalities) || return nothing
    variables = _linear_variables(inequalities)
    layers = Vector{Vector{_LinearInequality}}()
    for variable in variables
        push!(layers, inequalities)
        inequalities = _eliminate(inequalities, variable)
        all(_constant_satisfiable, inequalities) || return nothing
    end

    model = Dict{Symbol,Rational{BigInt}}()
    for (variable, layer) in zip(reverse(variables), reverse(layers))
        value = _reconstruct_value(layer, variable, model)
        value === nothing && return nothing
        model[variable] = value
    end
    model
end

function _negated_alternatives(constraint::LinearConstraint)
    if constraint.relation === :le
        return LinearConstraint[LinearConstraint(_negated_coefficients(constraint.coefficients),
                                                 :lt, -constraint.bound)]
    elseif constraint.relation === :lt
        return LinearConstraint[LinearConstraint(_negated_coefficients(constraint.coefficients),
                                                 :le, -constraint.bound)]
    end
    # ¬(a = b) is the disjunction a < b ∨ a > b. Keeping both branches
    # explicit avoids treating a failed equality as an unproved inequality.
    return LinearConstraint[
        LinearConstraint(copy(constraint.coefficients), :lt, constraint.bound),
        LinearConstraint(_negated_coefficients(constraint.coefficients), :lt, -constraint.bound),
    ]
end

function _theory_branches(assignment::Dict{Int,Bool}, atoms::AbstractDict{<:Integer,<:LinearConstraint})
    branches = [LinearConstraint[]]
    for (variable, value) in assignment
        atom = get(atoms, variable, nothing)
        atom === nothing && continue
        alternatives = value ? LinearConstraint[atom] : _negated_alternatives(atom)
        branches = [vcat(branch, alternative) for branch in branches for alternative in alternatives]
    end
    branches
end

function _linear_smt_dpll(clauses::Vector{Vector{Int}}, atoms, assignment::Dict{Int,Bool})
    any(linear_satisfiable, _theory_branches(assignment, atoms)) || return false
    isempty(clauses) && return true
    any(isempty, clauses) && return false

    literal = something(_unit_literal(clauses), first(first(clauses)))
    variable = abs(literal)
    value = literal > 0
    assignment[variable] = value
    if _linear_smt_dpll(_assign_literal(clauses, literal), atoms, assignment)
        return true
    end
    assignment[variable] = !value
    if _linear_smt_dpll(_assign_literal(clauses, -literal), atoms, assignment)
        return true
    end
    delete!(assignment, variable)
    false
end

function _linear_smt_model(clauses::Vector{Vector{Int}}, atoms,
                           assignment::Dict{Int,Bool})
    branches = _theory_branches(assignment, atoms)
    any(linear_satisfiable, branches) || return nothing
    if isempty(clauses)
        for branch in branches
            rationals = linear_model(branch)
            rationals === nothing || return (booleans=copy(assignment), rationals=rationals)
        end
        return nothing
    end
    any(isempty, clauses) && return nothing

    literal = something(_unit_literal(clauses), first(first(clauses)))
    variable = abs(literal)
    assignment[variable] = literal > 0
    model = _linear_smt_model(_assign_literal(clauses, literal), atoms, assignment)
    model !== nothing && return model

    assignment[variable] = literal < 0
    model = _linear_smt_model(_assign_literal(clauses, -literal), atoms, assignment)
    model !== nothing && return model

    delete!(assignment, variable)
    nothing
end

"""
    linear_smt_satisfiable(clauses, atoms) -> Bool

Decide a propositional CNF formula whose atoms are exact rational linear
constraints. `clauses` uses DIMACS literals and `atoms` maps each positive atom
number to a `LinearConstraint`. The solver combines the local pure-Julia DPLL
search with Fourier--Motzkin theory consistency checks.

Negated equality is expanded exactly into its strict-less-than and
strict-greater-than theory branches.
"""
function linear_smt_satisfiable(clauses::AbstractVector{<:AbstractVector{<:Integer}},
                                atoms::AbstractDict{<:Integer,<:LinearConstraint})
    normalized = _normalize_clauses(clauses)
    all(literal -> haskey(atoms, abs(literal)), Iterators.flatten(normalized)) ||
        throw(ArgumentError("every SMT literal must have a linear theory atom"))
    _linear_smt_dpll(normalized, atoms, Dict{Int,Bool}())
end

"""
    linear_smt_model(clauses, atoms) -> Union{NamedTuple, Nothing}

Return a checkable model for a satisfiable linear DPLL(T) problem. The result
has `booleans`, a DIMACS-variable assignment, and `rationals`, the exact
rational assignment for the selected linear-theory branch. Return `nothing`
when the problem is unsatisfiable.
"""
function linear_smt_model(clauses::AbstractVector{<:AbstractVector{<:Integer}},
                          atoms::AbstractDict{<:Integer,<:LinearConstraint})
    normalized = _normalize_clauses(clauses)
    all(literal -> haskey(atoms, abs(literal)), Iterators.flatten(normalized)) ||
        throw(ArgumentError("every SMT literal must have a linear theory atom"))
    model = _linear_smt_model(normalized, atoms, Dict{Int,Bool}())
    model === nothing && return nothing
    for literal in Iterators.flatten(normalized)
        get!(model.booleans, abs(literal), false)
    end
    model
end

export LinearConstraint, linear_satisfiable, linear_model, linear_smt_satisfiable, linear_smt_model
