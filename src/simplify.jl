using SymbolicUtils.Rewriters
import SymbolicUtils: simplify

export build_simplifier, simplify

"""
    OSRRule(name, description, rule)

A callable SymbolicUtils rewrite rule annotated with its stable OSR identity.
`name` defaults to the source document's `section:id` when rules are loaded
from JSON.
"""
struct OSRRule{R}
    name::String
    description::Union{Nothing,String}
    rule::R
end

(rule::OSRRule)(expr) = rule.rule(expr)
Base.show(io::IO, rule::OSRRule) = print(io, rule.name)

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
    simplify(expr, rules::AbstractVector; mode::Symbol=:fast, on_step=nothing)

Applies a set of OSR rules to an expression until it stops changing.
Supported modes:
- `:fast` : standard execution (default). Returns the result.
- `:trace` : returns a tuple `(result, steps_array)` where each step is a NamedTuple `(rule, before, after)`.

Set `on_step` to a callback to observe each rewrite without requiring output
from this library.  Rules loaded by `@load_osr` are `OSRRule` values, so trace
steps expose their stable `name` and human-readable `description`.
"""
function simplify(expr, rules::AbstractVector; mode::Symbol=:fast, assumptions=nothing, on_step=nothing)
    current = get(task_local_storage(), :osr_assumptions, nothing)
    merged_assumptions = if assumptions === nothing
        current
    elseif current === nothing
        assumptions
    else
        vcat(current, assumptions)
    end
    task_local_storage(:osr_assumptions, merged_assumptions) do
    if mode == :fast && on_step === nothing
        simplifier = build_simplifier(rules)
        return simplifier(expr)

    elseif mode == :fast || mode == :trace
        steps_array = NamedTuple[]
        function observe_rule(rule)
            return function(x)
                res = rule(x)
                if res !== nothing && !isequal(res, x)
                    step = (rule=rule, before=x, after=res)
                    mode == :trace && push!(steps_array, step)
                    on_step === nothing || on_step(step)
                end
                return res
            end
        end

        raw_chain = Rewriters.Chain(rules)
        traced_chain = Rewriters.instrument(raw_chain, observe_rule)
        walker = Rewriters.Postwalk(traced_chain)
        simplifier = Rewriters.Fixpoint(walker)
        result = simplifier(expr)
        return mode == :trace ? (result, steps_array) : result
    else
        throw(ArgumentError("Unknown mode: $mode. Use :fast or :trace."))
    end
    end
end
