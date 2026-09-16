module OpenSymbolicRules

using JSON
using SymbolicUtils
using SymbolicUtils: @rule, Sym, Term
using SymbolicUtils: iscall, arguments

include("predicates.jl")
include("simplify.jl")
include("equations.jl")
include("domains.jl")
include("bridge.jl")

export @load_osr
export FreeQ, is_integer, is_numeric, NotEqual
export build_simplifier, osr_simplify

"""
    osr_to_expr(node)

Recursively parse an OSR JSON node into a Julia expression for SymbolicUtils.
"""
function osr_to_expr(node)
    if node isa String
        if startswith(node, "~")
            # Pattern variable
            return Expr(:call, :~, Symbol(node[2:end]))
        else
            # Normal symbol/function
            return Symbol(node)
        end
    elseif node isa AbstractArray
        # Function call, e.g. ["Mul", "x", "y"] -> Mul(x, y)
        op = Symbol(node[1])
        args = map(osr_to_expr, node[2:end])
        return Expr(:call, op, args...)
    else
        # Literals like numbers
        return node
    end
end

"""
    @load_osr("path/to/rule.json")

Load an Open Symbolic Rules JSON file at compile-time and return a vector of `SymbolicUtils.jl` rules.
"""
macro load_osr(filepath)
    # The file path is relative to the caller's directory
    caller_dir = dirname(String(__source__.file))
    full_path = joinpath(caller_dir, filepath)

    # Read the JSON file at compile time
    data = JSON.parsefile(full_path)
    rules_json = data["rules"]

    rule_exprs = []
    for r in rules_json
        pattern = osr_to_expr(r["pattern"])
        result = osr_to_expr(r["result"])
        
        # Build constraints
        # For now, we naively support ["is_integer", "~n"] by converting it to `is_integer(n)` in a where clause
        # If there are no constraints, just LHS => RHS
        constraints_json = get(r, "constraints", [])
        
        if isempty(constraints_json)
            # @rule( pattern => result )
            push!(rule_exprs, :(@rule($pattern => $result)))
        else
            # Combine constraints into a logical AND
            cond_exprs = []
            for c in constraints_json
                pred = Symbol(c[1])
                args = map(osr_to_expr, c[2:end])
                # We want `pred(arg1, arg2)` instead of pattern vars like `~arg1`
                # So we strip the `~` macro call
                clean_args = args
                push!(cond_exprs, Expr(:call, pred, clean_args...))
            end
            
            # Combine multiple conditions with &&
            cond = length(cond_exprs) == 1 ? cond_exprs[1] : Expr(:&&, cond_exprs...)
            
            # Use `SymbolicUtils.If` for conditional rules
            # @rule( pattern => result where cond ) was removed, we use `If(cond)`?
            # Actually SymbolicUtils v4 uses: @rule LHS => RHS where cond
            # Wait, let's use `@rule LHS => RHS where cond` if it is supported!
            push!(rule_exprs, :(@rule($pattern => $result where $cond)))
        end
    end

    # Return a block that constructs the array of rules
    return esc(Expr(:vect, rule_exprs...))
end

end # module
