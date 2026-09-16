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
