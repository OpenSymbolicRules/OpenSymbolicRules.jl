# Basic Usage

This tutorial shows how to load and apply mathematical rules.

## Loading Rules
Rules are stored in JSON files. You can load them at compile-time using the `@load_osr` macro:

```julia
using OpenSymbolicRules

# Assuming you have cloned the Algebra rules into a specific directory
alg_rules = @load_osr("path/to/Algebra/1.1-basic-exponents.json")
```

## Simplifying Expressions
Once loaded, you can apply rules to `SymbolicUtils.jl` expressions using the `simplify` function.

```julia
using SymbolicUtils
@syms x Pow(a, b) Mul(a, b)

# Create an expression: (x^2)^3
expr = Pow(Pow(x, 2), 3)

# Simplify it
res = simplify(expr, alg_rules)
# -> Pow(x, 6)
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
