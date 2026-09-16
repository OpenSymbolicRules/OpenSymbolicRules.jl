using SymbolicUtils

# OSR Standard Calculus & Algebra Heads
@syms Derivative(a) Integral(a,b) Limit(a,b,c) BothSides
@syms Lambda(var, expr)

# Basic Arithmetic and Transcendentals (Uninterpreted to prevent implicit simplifications)
@syms Add(a, b) Multiply(a, b) Power(a, b) Divide(a, b) Subtract(a, b)
@syms Sin(a) Cos(a) Tan(a) Exp(a) Log(a)
@syms And(::Any, ::Any)::Any Or(::Any, ::Any)::Any Not(::Any)::Any
@syms Implies(::Any, ::Any)::Any Equivalent(::Any, ::Any)::Any
@syms Nand(::Any, ::Any)::Any Nor(::Any, ::Any)::Any
@syms Xor(::Any, ::Any)::Any Xnor(::Any, ::Any)::Any
@syms Forall(::Any, ::Any)::Any Exists(::Any, ::Any)::Any

# Export them so they are available in users' scopes
export Derivative, Integral, Limit, BothSides, Lambda
export Add, Multiply, Power, Divide, Subtract
export Sin, Cos, Tan, Exp, Log
export And, Or, Not, Implies, Equivalent, Nand, Nor, Xor, Xnor, Forall, Exists
