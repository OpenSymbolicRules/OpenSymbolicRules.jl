"""A small, exact propositional SAT kernel implemented entirely in Julia."""

function _normalize_clauses(clauses::AbstractVector{<:AbstractVector{<:Integer}})
    normalized = Vector{Vector{Int}}()
    for clause in clauses
        literals = Int.(clause)
        any(iszero, literals) && throw(ArgumentError("DIMACS literals must be nonzero"))
        unique!(literals)
        any(literal -> -literal in literals, literals) && continue
        push!(normalized, literals)
    end
    normalized
end

function _assign_literal(clauses::Vector{Vector{Int}}, literal::Int)
    simplified = Vector{Vector{Int}}()
    opposite = -literal
    for clause in clauses
        literal in clause && continue
        push!(simplified, filter(!=(opposite), clause))
    end
    simplified
end

function _unit_literal(clauses::Vector{Vector{Int}})
    for clause in clauses
        length(clause) == 1 && return only(clause)
    end
    nothing
end

function _dpll(clauses::Vector{Vector{Int}})::Bool
    isempty(clauses) && return true
    any(isempty, clauses) && return false

    unit = _unit_literal(clauses)
    unit !== nothing && return _dpll(_assign_literal(clauses, unit))

    literal = first(first(clauses))
    _dpll(_assign_literal(clauses, literal)) ||
        _dpll(_assign_literal(clauses, -literal))
end

"""
    satisfiable(clauses) -> Bool

Decide a propositional CNF formula using a pure-Julia DPLL implementation.
Each inner vector is a disjunction and the outer vector is a conjunction.
Literals use the DIMACS convention: positive `n` denotes variable `n`, and
negative `-n` denotes its negation. Literal zero is invalid.

This is deliberately a SAT foundation, not a claim to support all SMT theories.
It is the Boolean kernel on which a pure-Julia DPLL(T) layer can add equality,
rational arithmetic, and other theory solvers with explicit proof evidence.
"""
satisfiable(clauses::AbstractVector{<:AbstractVector{<:Integer}}) =
    _dpll(_normalize_clauses(clauses))

export satisfiable
