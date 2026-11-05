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
- it stops when no rule applies, or after `max_steps` steps
  (`r.exhausted == true`).

## What the certificate covers

A Lean certificate states that the rewrite is sound *where the pattern is
defined*: no zero divisor, no pole of `tan`, and so on. Under that condition,
the result has the same value as the input.

The certificate does **not** cover:

- the matcher, the substitution and the strategy implemented here. These are
  tested, not proved.
- termination. For example, the `default` Trigonometry profile contains two
  proved rules that rewrite `sin(x + y)` into an expression containing
  `sin(x + y)` again.
