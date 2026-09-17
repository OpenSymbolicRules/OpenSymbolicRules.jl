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
    inequalities = _LinearInequality[]
    for constraint in constraints
        append!(inequalities, _inequalities(constraint))
    end
    all(_constant_satisfiable, inequalities) || return false

    variables = Set{Symbol}()
    for inequality in inequalities
        union!(variables, keys(inequality.coefficients))
    end
    for variable in sort!(collect(variables))
        inequalities = _eliminate(inequalities, variable)
        all(_constant_satisfiable, inequalities) || return false
    end
    true
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

export LinearConstraint, linear_satisfiable, linear_smt_satisfiable
