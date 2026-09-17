using SymbolicUtils
using DomainSets
using IntervalSets

export ElementOf, ∈

"""
    ElementOf(var, domain)

The OSR form of a membership hypothesis: `var` lies in `domain`, which may be a
`DomainSets.jl` domain, an `IntervalSets.jl` interval, or a Julia type.  `∈`
builds one for a symbolic term, and the domain predicates read it through
[`entailed`](@ref).
"""
struct ElementOf
    var
    domain
end

# Fallback
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.Domain) = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::IntervalSets.AbstractInterval) = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::Type{<:Number}) = ElementOf(x, d)

# Resolve ambiguities against the interval methods DomainSets defines for each
# closure variant.
Base.in(x::SymbolicUtils.BasicSymbolic, d::IntervalSets.TypedEndpointsInterval{L, R, T}) where {L, R, T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.HalfLine{T, :closed}) where {T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.HalfLine{T, :open}) where {T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.NegativeHalfLine{T, :closed}) where {T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.NegativeHalfLine{T, :open}) where {T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.RealLine{T}) where {T} = ElementOf(x, d)
Base.in(x::SymbolicUtils.BasicSymbolic, d::DomainSets.Interval{L, R, T}) where {L, R, T} = ElementOf(x, d)

Base.show(io::IO, el::ElementOf) = print(io, el.var, " ∈ ", el.domain)
Base.isequal(a::ElementOf, b::ElementOf) = isequal(a.var, b.var) && isequal(a.domain, b.domain)
Base.:(==)(a::ElementOf, b::ElementOf) = isequal(a, b)
