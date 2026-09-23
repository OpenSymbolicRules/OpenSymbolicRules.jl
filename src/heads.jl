using SymbolicUtils

# OSR Standard Calculus & Algebra Heads.  Their operands are unconstrained
# because a lambda body, an integrand, or a limit point may be a proposition or
# a piecewise just as well as a number.  They keep the `Number` result type of
# the arithmetic heads so that they compose with them.
@syms Derivative(::Any)::Number Integral(::Any, ::Any)::Number
@syms Limit(::Any, ::Any, ::Any)::Number BothSides
@syms Lambda(::Any, ::Any)::Number
# The OSR expression grammar requires a head to be a name (OSR-X-004), so a
# lambda cannot stand in head position and an application needs a head of its
# own.  `beta_reduce` is what carries one out.
@syms Apply(::Any, ::Any)::Number

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
export Derivative, Integral, Limit, BothSides, Lambda, Apply
export Add, Multiply, Power, Divide, Subtract
export Sin, Cos, Tan, Cot, Sec, Csc, Sinh, Cosh, Tanh, Coth, Sech, Csch
export Asin, Acos, Atan, Acot, Asec, Acsc, Asinh, Acosh, Atanh, Acoth, Asech, Acsch
export Exp, Log, Sqrt
export And, Or, Not, Implies, Equivalent, Nand, Nor, Xor, Xnor, Forall, Exists
export Piecewise, Piece, Otherwise

"""
    Simp(u)
    Simp(u, x)

Return `u`.

The corpus writes both arities: `Simp[u]` 200 times and `Simp[u, x]` 518 times.

RUBI writes `Simp[u, x]` for "`u`, tidied up with respect to `x`". Tidying is
optional: the expression it names is `u` either way, so returning `u` is exact
rather than approximate, and the rewrite that produced it stays valid.

What matters is that it is *not* an inert head. A rule whose result is wrapped
in an uninterpreted `Simp` can never be matched by the rule that should come
next, which stops the rewrite chain after one step — two thirds of the problems
that stalled in section 1.1.1 stalled on `Simp` or `ExpandIntegrand`.

`ExpandIntegrand` is deliberately not given the same reading. It too denotes an
expression equal to its argument, but `Int(ExpandIntegrand(u, x), x)` would then
become the integral it came from, and the rewrite would not terminate.
"""
Simp(u) = u
Simp(u, x) = u

"""
    Subst(expression, variable, replacement)

Substitute `variable` by `replacement` in `expression`.

This is the operational reading required by OSR-E-012 for the `Subst` utility
head emitted by integration rules.  It delegates to [`osr_substitute`](@ref),
so lexical binders are respected and a replacement cannot be captured by a
lambda, quantifier, or other OSR binder.
"""
Subst(expression, variable, replacement) =
    osr_substitute(expression, variable => replacement)

"""
    Dist(u, v, x)

Return `u*v`.

RUBI writes `Dist[u, v, x]` to push the factor `u` inside `v`, whether `v` is a
sum or an integral. The value it denotes is `u*v` whichever it does, so the
product is the whole of its meaning; only the shape of the answer differs, and
that shape is what the rules downstream restore.
"""
Dist(u, v, x) = Multiply(u, v)

export Simp, Subst, Dist
