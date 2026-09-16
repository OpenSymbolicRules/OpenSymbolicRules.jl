using SymbolicUtils
using SymbolicUtils.Rewriters

export bridge_to_osr, bridge_from_osr

# We define the canonical pedagogical Derivative symbol used in OSR Calculus
@syms Derivative(expr, var)

"""
    bridge_to_osr(expr)

Converts `Symbolics.jl` operations into `OpenSymbolicRules.jl` pedagogical format.
Specifically, it converts `Symbolics.Differential(x)(expr)` into `Derivative(expr, x)`.
"""
function bridge_to_osr(expr)
    Rewriters.Postwalk(x -> begin
        if iscall(x)
            op = operation(x)
            # Duck-typing: Check if the operation is a Symbolics Differential
            if typeof(op).name.name == :Differential || typeof(op).name.name == :MockDifferential
                var = op.x
                return term(Derivative, arguments(x)[1], var)
            end
        end
        return x
    end)(expr)
end

"""
    bridge_from_osr(expr; Differential)

Converts `OpenSymbolicRules.jl` pedagogical format back into `Symbolics.jl` operations.
Specifically, it converts `Derivative(expr, x)` into `Differential(x)(expr)`.

You must pass the `Symbolics.Differential` constructor as a keyword argument 
(e.g., `bridge_from_osr(expr, Differential=Symbolics.Differential)`).
"""
function bridge_from_osr(expr; Differential=nothing)
    if Differential === nothing
        throw(ArgumentError("You must provide the Symbolics.Differential constructor. E.g.: bridge_from_osr(expr, Differential=Symbolics.Differential)"))
    end
    Rewriters.Postwalk(x -> begin
        if iscall(x)
            op = operation(x)
            if isequal(op, Derivative)
                expr_arg = arguments(x)[1]
                var_arg = arguments(x)[2]
                return term(Differential(var_arg), expr_arg)
            end
        end
        return x
    end)(expr)
end
