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

function _dpll_model(clauses::Vector{Vector{Int}}, assignment::Dict{Int,Bool})
    isempty(clauses) && return copy(assignment)
    any(isempty, clauses) && return nothing

    literal = something(_unit_literal(clauses), first(first(clauses)))
    variable = abs(literal)
    assignment[variable] = literal > 0
    model = _dpll_model(_assign_literal(clauses, literal), assignment)
    model !== nothing && return model

    assignment[variable] = literal < 0
    model = _dpll_model(_assign_literal(clauses, -literal), assignment)
    model !== nothing && return model

    delete!(assignment, variable)
    nothing
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

"""
    sat_model(clauses) -> Union{Dict{Int,Bool}, Nothing}

Return a Boolean model for a satisfiable DIMACS CNF formula, or `nothing` when
it is unsatisfiable. The returned dictionary is a directly checkable witness:
every input clause contains at least one literal whose variable has the stated
truth value.
"""
function sat_model(clauses::AbstractVector{<:AbstractVector{<:Integer}})
    normalized = _normalize_clauses(clauses)
    model = _dpll_model(normalized, Dict{Int,Bool}())
    model === nothing && return nothing
    for literal in Iterators.flatten(normalized)
        get!(model, abs(literal), false)
    end
    model
end

struct _SATState
    problem::SATProblem
    backend::CASBackend
    options::SolveOptions
end

CommonSolve.init(problem::SATProblem, backend::CASBackend=BuiltinBackend();
                  options::SolveOptions=SolveOptions()) =
    _SATState(problem, backend, options)

function CommonSolve.solve!(state::_SATState)
    state.backend isa BuiltinBackend || return UnknownResult(:unsupported_backend, state.backend)
    state.options.require_certificate && return UnknownResult(:certificate_unavailable, state.backend)
    model = sat_model(state.problem.clauses)
    model === nothing ? UnsatResult(state.backend) : SatResult(model, state.backend)
end

export satisfiable, sat_model
