using SymbolicUtils

# OSR Standard Calculus & Algebra Heads
@syms Derivative(a) Integral(a,b) Limit(a,b,c) BothSides
@syms Lambda(var, expr)

# Basic Arithmetic and Transcendentals (Uninterpreted to prevent implicit simplifications)
@syms Add(a, b) Multiply(a, b) Power(a, b) Divide(a, b) Subtract(a, b)
@syms Sin(a) Cos(a) Tan(a) Exp(a) Log(a)

# Export them so they are available in users' scopes
export Derivative, Integral, Limit, BothSides, Lambda
export Add, Multiply, Power, Divide, Subtract
export Sin, Cos, Tan, Exp, Log
