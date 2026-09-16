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
    simplify(expr, rules::AbstractVector; mode::Symbol=:fast)

Applies a set of OSR rules to an expression until it stops changing.
Supported modes:
- `:fast` : standard execution (default). Returns the result.
- `:trace` : returns a tuple `(result, steps_array)` where each step is a NamedTuple `(rule, before, after)`.
- `:verbose` : prints each step to the standard output and returns the result.
"""
function simplify(expr, rules::AbstractVector; mode::Symbol=:fast)
    if mode == :fast
        simplifier = build_simplifier(rules)
        return simplifier(expr)
        
    elseif mode == :trace
        steps_array = []
        function trace_rule(r)
            return function(x)
                res = r(x)
                if res !== nothing && !isequal(res, x)
                    push!(steps_array, (rule=r, before=x, after=res))
                end
                return res
            end
        end
        
        # Build raw simplifier then instrument it
        raw_chain = Rewriters.Chain(rules)
        traced_chain = Rewriters.instrument(raw_chain, trace_rule)
        walker = Rewriters.Postwalk(traced_chain)
        simplifier = Rewriters.Fixpoint(walker)
        
        result = simplifier(expr)
        return result, steps_array
        
    elseif mode == :verbose
        function verbose_rule(r)
            return function(x)
                res = r(x)
                if res !== nothing && !isequal(res, x)
                    println("STEP: ", x, "  =>  ", res)
                    # Note: Symbolics Rules don't have built-in names, we just print the rule object
                    println("RULE: ", r, "\n")
                end
                return res
            end
        end
        
        raw_chain = Rewriters.Chain(rules)
        traced_chain = Rewriters.instrument(raw_chain, verbose_rule)
        walker = Rewriters.Postwalk(traced_chain)
        simplifier = Rewriters.Fixpoint(walker)
        
        return simplifier(expr)
        
    else
        throw(ArgumentError("Unknown mode: $mode. Use :fast, :trace, or :verbose."))
    end
end
