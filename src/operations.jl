"""Common problem, backend, and result types for CAS operations."""
abstract type CASProblem end
abstract type CASResult end
abstract type CASBackend end

"""The pure-Julia algorithms bundled with OpenSymbolicRules.jl."""
struct BuiltinBackend <: CASBackend end

"""Resource and evidence requirements supplied to a CAS operation."""
Base.@kwdef struct SolveOptions
    exact::Bool = true
    require_certificate::Bool = false
end

"""A propositional CNF formula whose literals use the DIMACS convention."""
struct SATProblem <: CASProblem
    clauses::Vector{Vector{Int}}
    function SATProblem(clauses::AbstractVector{<:AbstractVector{<:Integer}})
        new(_normalize_clauses(clauses))
    end
end

"""A CNF problem with atoms owned by one built-in SMT theory."""
struct SMTProblem{A} <: CASProblem
    clauses::Vector{Vector{Int}}
    atoms::Dict{Int,A}
    function SMTProblem(clauses::AbstractVector{<:AbstractVector{<:Integer}}, atoms::AbstractDict{<:Integer,A}) where {A}
        new{A}(_normalize_clauses(clauses), Dict{Int,A}(Int(key) => value for (key, value) in atoms))
    end
end

struct SatResult{T} <: CASResult
    model::T
    backend::CASBackend
end

struct UnsatResult <: CASResult
    backend::CASBackend
end

struct UnknownResult <: CASResult
    reason::Symbol
    backend::CASBackend
end

export CASProblem, CASResult, CASBackend, BuiltinBackend, SolveOptions
export SATProblem, SMTProblem, SatResult, UnsatResult, UnknownResult, solve
