"""Ground equality theory for the pure-Julia SMT foundation."""

struct EqualityConstraint
    left::Symbol
    right::Symbol
    relation::Symbol

    function EqualityConstraint(left::Symbol, right::Symbol, relation::Symbol)
        relation in (:eq, :ne) ||
            throw(ArgumentError("equality constraints support only :eq and :ne"))
        new(left, right, relation)
    end
end

function _find_root!(parent::Dict{Symbol,Symbol}, value::Symbol)
    root = get!(parent, value, value)
    root == value && return value
    parent[value] = _find_root!(parent, root)
end

function _merge!(parent::Dict{Symbol,Symbol}, left::Symbol, right::Symbol)
    left_root = _find_root!(parent, left)
    right_root = _find_root!(parent, right)
    left_root == right_root || (parent[right_root] = left_root)
end

"""
    equality_satisfiable(constraints) -> Bool

Decide conjunctions of ground equality and disequality constraints over
uninterpreted symbols. Equalities are closed transitively with a pure-Julia
union-find structure before all disequalities are checked.
"""
function _equality_parent(constraints::AbstractVector{<:EqualityConstraint})
    parent = Dict{Symbol,Symbol}()
    for constraint in constraints
        constraint.relation === :eq || continue
        _merge!(parent, constraint.left, constraint.right)
    end
    all(constraint -> constraint.relation === :eq ||
        _find_root!(parent, constraint.left) != _find_root!(parent, constraint.right), constraints) ||
        return nothing
    parent
end

equality_satisfiable(constraints::AbstractVector{<:EqualityConstraint}) =
    _equality_parent(constraints) !== nothing

"""
    equality_model(constraints) -> Union{Dict{Symbol,Symbol}, Nothing}

Return the equivalence-class representative for every term occurring in a
satisfiable ground equality problem, or `nothing` if its disequalities
contradict the equality closure. The returned map is a checkable model for the
equality theory: equal terms have equal representatives.
"""
function equality_model(constraints::AbstractVector{<:EqualityConstraint})
    parent = _equality_parent(constraints)
    parent === nothing && return nothing
    terms = Set{Symbol}()
    for constraint in constraints
        push!(terms, constraint.left, constraint.right)
    end
    Dict(term => _find_root!(parent, term) for term in terms)
end

_negate(constraint::EqualityConstraint) = EqualityConstraint(
    constraint.left, constraint.right, constraint.relation === :eq ? :ne : :eq)

function _equality_constraints(assignment::Dict{Int,Bool},
                               atoms::AbstractDict{<:Integer,<:EqualityConstraint})
    constraints = EqualityConstraint[]
    for (variable, value) in assignment
        atom = get(atoms, variable, nothing)
        atom === nothing || push!(constraints, value ? atom : _negate(atom))
    end
    constraints
end

function _equality_smt_dpll(clauses::Vector{Vector{Int}}, atoms,
                            assignment::Dict{Int,Bool})
    equality_satisfiable(_equality_constraints(assignment, atoms)) || return false
    isempty(clauses) && return true
    any(isempty, clauses) && return false

    literal = something(_unit_literal(clauses), first(first(clauses)))
    variable = abs(literal)
    value = literal > 0
    assignment[variable] = value
    if _equality_smt_dpll(_assign_literal(clauses, literal), atoms, assignment)
        return true
    end
    assignment[variable] = !value
    if _equality_smt_dpll(_assign_literal(clauses, -literal), atoms, assignment)
        return true
    end
    delete!(assignment, variable)
    false
end

function _equality_smt_model(clauses::Vector{Vector{Int}}, atoms,
                             assignment::Dict{Int,Bool})
    constraints = _equality_constraints(assignment, atoms)
    equality_satisfiable(constraints) || return nothing
    if isempty(clauses)
        classes = equality_model(constraints)
        return (booleans=copy(assignment), classes=classes)
    end
    any(isempty, clauses) && return nothing

    literal = something(_unit_literal(clauses), first(first(clauses)))
    variable = abs(literal)
    assignment[variable] = literal > 0
    model = _equality_smt_model(_assign_literal(clauses, literal), atoms, assignment)
    model !== nothing && return model

    assignment[variable] = literal < 0
    model = _equality_smt_model(_assign_literal(clauses, -literal), atoms, assignment)
    model !== nothing && return model

    delete!(assignment, variable)
    nothing
end

"""
    smt_satisfiable(clauses, atoms) -> Bool

Decide CNF Boolean clauses over ground equality atoms. Clauses use DIMACS
literals and `atoms` maps each positive number to an `EqualityConstraint`.
This is a pure-Julia DPLL(T) entry point for the equality theory.
"""
function smt_satisfiable(clauses::AbstractVector{<:AbstractVector{<:Integer}},
                         atoms::AbstractDict{<:Integer,<:EqualityConstraint})
    normalized = _normalize_clauses(clauses)
    all(literal -> haskey(atoms, abs(literal)), Iterators.flatten(normalized)) ||
        throw(ArgumentError("every SMT literal must have an equality theory atom"))
    _equality_smt_dpll(normalized, atoms, Dict{Int,Bool}())
end

"""
    smt_model(clauses, atoms) -> Union{NamedTuple, Nothing}

Return a checkable model for CNF clauses over ground equality atoms. The result
contains the Boolean `booleans` assignment and the equality `classes` map, or
`nothing` when the problem is unsatisfiable.
"""
function smt_model(clauses::AbstractVector{<:AbstractVector{<:Integer}},
                   atoms::AbstractDict{<:Integer,<:EqualityConstraint})
    normalized = _normalize_clauses(clauses)
    all(literal -> haskey(atoms, abs(literal)), Iterators.flatten(normalized)) ||
        throw(ArgumentError("every SMT literal must have an equality theory atom"))
    model = _equality_smt_model(normalized, atoms, Dict{Int,Bool}())
    model === nothing && return nothing
    for literal in Iterators.flatten(normalized)
        get!(model.booleans, abs(literal), false)
    end
    model
end

function CommonSolve.solve!(state::_SMTState{EqualityConstraint})
    state.backend isa BuiltinBackend || return UnknownResult(:unsupported_backend, state.backend)
    state.options.require_certificate && return UnknownResult(:certificate_unavailable, state.backend)
    model = smt_model(state.problem.clauses, state.problem.atoms)
    model === nothing ? UnsatResult(state.backend) : SatResult(model, state.backend)
end

export EqualityConstraint, equality_satisfiable, equality_model, smt_satisfiable, smt_model
