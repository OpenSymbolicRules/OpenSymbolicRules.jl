module OpenSymbolicRulesGiacExt

using OpenSymbolicRules
using Giac

"""
    to_giac(expr)

Convert an OpenSymbolicRules (SymbolicUtils) expression to a GiacExpr by evaluating
its string representation in the Giac context.
"""
function OpenSymbolicRules.to_giac(expr)
    # The string representation of a SymbolicUtils tree matches standard math syntax
    # which Giac can parse perfectly.
    return Giac.giac_eval(string(expr))
end

"""
    to_osr(expr::Giac.GiacExpr)

Convert a GiacExpr back to an OpenSymbolicRules expression.
This currently requires `Symbolics.jl` to be loaded in your session,
as it relies on Giac's native `to_symbolics` extension.

# Example
```julia
using Giac, OpenSymbolicRules, Symbolics
g = giac_eval("x^2 + 1")
osr_expr = to_osr(g)
```
"""
function OpenSymbolicRules.to_osr(expr::Giac.GiacExpr)
    # Check if the to_symbolics method is available (it is defined in GiacSymbolicsExt)
    try
        sym_num = Giac.to_symbolics(expr)
        # sym_num is a Symbolics.Num. We unwrap it to get the raw SymbolicUtils.BasicSymbolic
        if hasproperty(sym_num, :val)
            return sym_num.val
        else
            # Fallback if Symbolics changes its internal structure
            return sym_num 
        end
    catch e
        if e isa MethodError
            error("`to_osr` for GiacExpr requires Symbolics.jl to be loaded. Please run `using Symbolics` first.")
        else
            rethrow(e)
        end
    end
end

end
