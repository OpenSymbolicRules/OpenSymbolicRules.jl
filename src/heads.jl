using SymbolicUtils

# OSR Standard Calculus & Algebra Heads.  Their operands are unconstrained
# because a lambda body, an integrand, or a limit point may be a proposition or
# a piecewise just as well as a number.  They keep the `Number` result type of
# the arithmetic heads so that they compose with them.
@syms Derivative(::Any)::Number Integral(::Any, ::Any)::Number
@syms Limit(::Any, ::Any, ::Any)::Number BothSides
@syms Lambda(::Any, ::Any)::Number

# Basic Arithmetic and Transcendentals (Uninterpreted to prevent implicit simplifications)
@syms Add(a, b) Multiply(a, b) Power(a, b) Divide(a, b) Subtract(a, b)
@syms Sin(a) Cos(a) Tan(a) Cot(a) Sec(a) Csc(a)
@syms Sinh(a) Cosh(a) Tanh(a) Coth(a) Sech(a) Csch(a)
@syms Asin(a) Acos(a) Atan(a) Acot(a) Asec(a) Acsc(a)
@syms Asinh(a) Acosh(a) Atanh(a) Acoth(a) Asech(a) Acsch(a)
@syms Exp(a) Log(a) Sqrt(a)
@syms And(::Any, ::Any)::Any Or(::Any, ::Any)::Any Not(::Any)::Any
@syms Implies(::Any, ::Any)::Any Equivalent(::Any, ::Any)::Any
@syms Nand(::Any, ::Any)::Any Nor(::Any, ::Any)::Any
@syms Xor(::Any, ::Any)::Any Xnor(::Any, ::Any)::Any
@syms Forall(::Any, ::Any)::Any Exists(::Any, ::Any)::Any

# Piecewise branches, carrying the validity conditions of real and complex
# domains, absolute values, roots, and logarithms.
# A branch list is a collection and a condition is a truth value, so neither is
# constrained to `Number` the way the arithmetic heads are.
@syms Piecewise(::Any)::Number Piece(::Any, ::Any)::Any Otherwise(::Any)::Any

# Export them so they are available in users' scopes
export Derivative, Integral, Limit, BothSides, Lambda
export Add, Multiply, Power, Divide, Subtract
export Sin, Cos, Tan, Cot, Sec, Csc, Sinh, Cosh, Tanh, Coth, Sech, Csch
export Asin, Acos, Atan, Acot, Asec, Acsc, Asinh, Acosh, Atanh, Acoth, Asech, Acsch
export Exp, Log, Sqrt
export And, Or, Not, Implies, Equivalent, Nand, Nor, Xor, Xnor, Forall, Exists
export Piecewise, Piece, Otherwise
