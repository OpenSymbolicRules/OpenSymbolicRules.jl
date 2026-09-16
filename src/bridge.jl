using SymbolicUtils

export bridge_to_osr, bridge_from_osr, Derivative

# We define the canonical pedagogical Derivative symbol used in OSR Calculus
@syms Derivative(expr, var)

"""
    bridge_to_osr(expr)

Converts `Symbolics.jl` operations into `OpenSymbolicRules.jl` pedagogical format.
Requires loading `Symbolics` first (`using Symbolics`).
"""
function bridge_to_osr end

"""
    bridge_from_osr(expr)

Converts `OpenSymbolicRules.jl` pedagogical format back into `Symbolics.jl` operations.
Requires loading `Symbolics` first (`using Symbolics`).
"""
function bridge_from_osr end
