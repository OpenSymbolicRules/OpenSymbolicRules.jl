using SymbolicUtils.Rewriters

export build_simplifier, osr_simplify

"""
    build_simplifier(rules::AbstractVector)

Builds a fixed-point bottom-up rewriter from a vector of `SymbolicUtils` rules.
"""
function build_simplifier(rules::AbstractVector)
    chain = Rewriters.Chain(rules)
    walker = Rewriters.Postwalk(chain)
    return Rewriters.Fixpoint(walker)
end

"""
    osr_simplify(expr, rules::AbstractVector)

Applies a set of OSR rules to an expression until it stops changing.
"""
function osr_simplify(expr, rules::AbstractVector)
    simplifier = build_simplifier(rules)
    return simplifier(expr)
end
