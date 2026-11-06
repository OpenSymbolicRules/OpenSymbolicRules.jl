# Verified rules from Lean (OSR v1)

`OpenSymbolicRules.OSRv1` reads the OSR v1 interchange format. That format is
generated from rules authored and proved in Lean 4 with Mathlib
([OpenSymbolicRules/Lean](https://github.com/OpenSymbolicRules/Lean)).

You do not need Lean to use these rules.

## Loading a rule set

```julia
using OpenSymbolicRules.OSRv1

rs = load_ruleset("trigonometry.osr.json")
rule = rs.rules["trigonometry.pythagorean"]

rule.symbols                 # OpenMath symbols, e.g. OMS("transc1", "sin")
v = verification(rule, :real)
v.status, v.certified        # ("proved", true)
v.theorem                    # "OSR.Trigonometry.pythagorean_real"
v.axioms                     # ["Classical.choice", "Quot.sound", "propext"]
```

Each rule has one verification record per domain (`:real`, `:complex`).

A record is **certified** when two things hold:

- its Lean theorem is proved using the standard axioms only;
- every OpenMath symbol the rule uses has a reviewed or formally related Lean
  interpretation in that domain.

For example, `trigonometry.inverse.tan_arctan` is certified over ℝ but not over
ℂ.

## Rewriting

Expressions are OpenMath objects, built with `OMS`, `OMV`, `OMI` and `OMA`, or
parsed from OpenMath JSON with `parse_omjson`.

```julia
sin(e) = OMA(OMS("transc1", "sin"), [e])
cos(e) = OMA(OMS("transc1", "cos"), [e])
sq(e)  = OMA(OMS("arith1", "power"), [e, OMI(2)])
plus(a, b) = OMA(OMS("arith1", "plus"), [a, b])

t = OMV("t")
r = rewrite(plus(sq(sin(t)), sq(cos(t))), rs; profile = "default", domain = :real)
r.expr             # OMI(1)
r.steps[1].rule    # "trigonometry.pythagorean"
```

`rewrite` uses only certified rules by default. Pass `certified_only = false`
to also use rules that are proved but not certified.

The strategy works as follows:

- it is outermost-first and leftmost;
- it tries rules in profile order;
- it stops when no rule applies, or after `max_steps` steps.
  `r.exhausted` is `true` when the budget is spent and a rule still applies.

This is the strategy of the Lean reference rewriter `OSR.normalize`, whose
soundness is proved in Lean. The Trigonometry rule set has four profiles
(`default` for expansion, `product_to_sum`, `power_reduction` and
`sum_to_product`), the Algebra rule set two (`default` and
`factor_polynomials`) and the Logic rule set three (`default`, `to_cnf`,
`to_dnf`, in the `:boolean` domain); the termination of each profile is
proved in Lean.

## Conformance

The Lean exporter also writes conformance cases: for each profile and input,
the expected result and the sequence of rule ids applied. They are published
in `OpenSymbolicRules/Conformance`, and `test/test_osr_v1.jl` checks that
`rewrite` reproduces all of them, for Trigonometry, Algebra, Logic and Calculus (fixtures in
`test/data/osr1/`; set `OSR1_DIR` to a Lean export directory to use fresh
files instead).

## What the certificate covers

A Lean certificate states that the rewrite is sound *where the pattern is
defined*: no zero divisor, no pole of `tan`, and so on. Under that condition,
the result has the same value as the input.

The certificate does **not** cover:

- the matcher, the substitution and the strategy implemented here. The Lean
  reference rewriter is proved sound; this implementation is only tested
  against its conformance cases.
- termination. It is tested on the profile seeds, not proved. Each rule of the
  v0.1 profiles was correct, but `sin(x + y)` was rewritten into an expression
  containing `sin(x + y)` again; v1 profiles avoid such cycles.
