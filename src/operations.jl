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

struct SatResult <: CASResult
    model::Dict{Int,Bool}
    backend::CASBackend
end

struct UnsatResult <: CASResult
    backend::CASBackend
end

struct UnknownResult <: CASResult
    reason::Symbol
    backend::CASBackend
end

"""Solve a structured CAS problem with an explicitly selected backend."""
function solve end

export CASProblem, CASResult, CASBackend, BuiltinBackend, SolveOptions
export SATProblem, SatResult, UnsatResult, UnknownResult, solve
