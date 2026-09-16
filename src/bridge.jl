using SymbolicUtils

export to_osr, to_symbolics, Derivative

# We define the canonical pedagogical Derivative symbol used in OSR Calculus
@syms Derivative(expr, var)

"""
    to_osr(expr)

Converts `Symbolics.jl` operations into `OpenSymbolicRules.jl` pedagogical format.
Requires loading `Symbolics` first (`using Symbolics`).
"""
function to_osr end

"""
    to_symbolics(expr)

Converts `OpenSymbolicRules.jl` pedagogical format back into `Symbolics.jl` operations.
Requires loading `Symbolics` first (`using Symbolics`).
"""
function to_symbolics end
