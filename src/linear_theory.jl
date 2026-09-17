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

export LinearConstraint, linear_satisfiable
