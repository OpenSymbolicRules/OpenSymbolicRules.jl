using SymbolicUtils.Rewriters
import SymbolicUtils: simplify

export build_simplifier, simplify

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
    simplify(expr, rules::AbstractVector; steps::Bool=false)

Applies a set of OSR rules to an expression until it stops changing.
If `steps=true`, returns a tuple `(result, steps_array)` where each step 
is a NamedTuple `(rule, before, after)`. Otherwise, returns only the `result`.
"""
function simplify(expr, rules::AbstractVector; steps::Bool=false)
    if steps
        steps_array = []
        logged_rules = map(rules) do r
            return function(x)
                res = r(x)
                if res !== nothing && !isequal(res, x)
                    push!(steps_array, (rule=r, before=x, after=res))
                end
                return res
            end
        end
        simplifier = build_simplifier(logged_rules)
        result = simplifier(expr)
        return result, steps_array
    else
        simplifier = build_simplifier(rules)
        return simplifier(expr)
    end
end
