using SymbolicUtils.Rewriters

export build_simplifier, osr_simplify, step_simplify

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

"""
    step_simplify(expr, rules::AbstractVector)

Applies a set of OSR rules to an expression, recording each transformation step.
Returns `(result, steps)` where `steps` is an array of NamedTuples `(rule, before, after)`.
"""
function step_simplify(expr, rules::AbstractVector)
    steps = []
    
    # Wrap each rule to log its application
    logged_rules = map(rules) do r
        return function(x)
            res = r(x)
            if res !== nothing && !isequal(res, x)
                push!(steps, (rule=r, before=x, after=res))
            end
            return res
        end
    end
    
    simplifier = build_simplifier(logged_rules)
    result = simplifier(expr)
    
    return result, steps
end
