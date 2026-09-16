# Basic Usage

This tutorial shows how to load and apply mathematical rules.

## Loading Rules
Rules are stored in JSON files. You can load them at compile-time using the `@load_osr` macro:

```julia
using OpenSymbolicRules

# Assuming you have cloned the Algebra rule repository
alg_rules = @load_osr_profile("path/to/Algebra")
```

The loader verifies that every mathematical operator used by the selected rule
files has an `openmath:<content-dictionary>#<symbol>` declaration in its
`semantics` object. Constraint predicates are intentionally exempt.

## Simplifying Expressions
Once loaded, you can apply rules to `SymbolicUtils.jl` expressions using the `simplify` function.

```julia
using SymbolicUtils
@syms x Power(a, b) Multiply(a, b)

# Create an expression: (x^2)^3
expr = Power(Power(x, 2), 3)

# Simplify it
res = simplify(expr, alg_rules)
# -> Power(x, Multiply(2, 3))
```

## Step-by-Step Tracing
For educational purposes, you can trace the intermediate steps:

```julia
res, steps = simplify(expr, alg_rules; mode=:trace)

for step in steps
    println("Before: ", step.before)
    println("After:  ", step.after)
    println("Rule used: ", step.rule.name)
end
```

Rules loaded from JSON retain their stable OSR name (`section:id`) and their
description. For streaming output, logging, or a graphical interface, pass a
callback instead of relying on the library to print:

```julia
simplify(expr, alg_rules; on_step=step -> @info "rewrite" rule=step.rule.name)
```

## Assumptions and Safe Rewrites

Rules carrying a predicate are applied only when it is established.  For
example, `NonzeroQ` is mapped to `is_nonzero`: it accepts a nonzero literal,
or a symbolic term explicitly declared nonzero.  This prevents the invalid
unconditional rewrite `0^0 = 1`.

```julia
@syms x Power(a, b)
power_rules = @load_osr("path/to/1.1-basic-exponents.json")

simplify(Power(x, 0), power_rules)                         # unchanged
simplify(Power(x, 0), power_rules; assumptions=[IsNonzero(x)]) # 1
```

## Loading a Profile

An OSR repository can expose an ordered default profile and named rewrite
profiles in `rules/meta.json`:

```julia
rules = @load_osr_profile("path/to/Logic")
cnf_rules = @load_osr_profile("path/to/Logic", :to_cnf)
```

Multi-premise inference profiles are read as structured data, leaving proof
search and clause management to the host engine:

```julia
inferences = load_inference_profile("path/to/Logic", :resolution)
```

Logic profiles use the exported canonical heads `And`, `Or`, `Not`, `Implies`,
`Equivalent`, `Forall`, and `Exists`.

Quantifier heads accept a vector of bound variable names.  A rule declaration
using `xs__` captures and preserves the complete vector, so a first-order
rewrite can handle one or many bound variables without treating that vector as
a scalar expression:

```julia
@syms p
rules = @load_osr("path/to/6.1-negation.json")
simplify(Not(Forall([:x, :y], p)), rules) # Exists([:x, :y], Not(p))
```

OpenMath n-ary `Add`, `Multiply`, `And`, and `Or` expressions are normalized
to left-associated binary SymbolicUtils terms at load time. Commutative
matching is supported for binary `Add`, `And`, and `Or` forms; `Multiply` is
not reordered because symbolic operands may be matrices. Full
associative-commutative matching remains a separate optimisation.

With Symbolics.jl, symbolic arrays can be declared with
`@variables A[1:m, 1:n]`. Matrix addition may use `Add` when dimensions are
compatible, but matrix multiplication must retain its operand order. A future
matrix profile will need explicit shape constraints and matrix-product
semantics rather than scalar `arith1#times` assumptions.

The same rule is stricter for tensors: addition is commutative only for equal
shapes, whereas tensor product, contraction, and axis permutation are ordered
operations. They must be represented by dedicated heads with explicit index
and shape metadata; they must never be silently encoded as `Multiply`.
