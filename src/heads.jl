using SymbolicUtils

# OSR Standard Calculus & Algebra Heads
@syms Derivative(a) Integral(a,b) Limit(a,b,c) BothSides
@syms Lambda(var, expr)

# Basic Arithmetic and Transcendentals (Uninterpreted to prevent implicit simplifications)
@syms Add(a, b) Multiply(a, b) Power(a, b) Divide(a, b) Subtract(a, b)
@syms Sin(a) Cos(a) Tan(a) Exp(a) Log(a)
@syms And(a, b) Or(a, b) Not(a) Implies(a, b) Equivalent(a, b)
@syms Nand(a, b) Nor(a, b) Xor(a, b) Xnor(a, b)
@syms Forall(variables, body) Exists(variables, body)

# Export them so they are available in users' scopes
export Derivative, Integral, Limit, BothSides, Lambda
export Add, Multiply, Power, Divide, Subtract
export Sin, Cos, Tan, Exp, Log
export And, Or, Not, Implies, Equivalent, Nand, Nor, Xor, Xnor, Forall, Exists
