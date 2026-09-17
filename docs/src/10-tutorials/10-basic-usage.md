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

## Proving an equivalence

`prove` searches for a rewrite path between two expressions and returns the
proof that records it:

```julia
@syms x
rules = @load_osr_profile("path/to/Trigonometry")

proof = prove(Add(Power(Sin(x), 2), Power(Cos(x), 2)), 1, rules)
verified(proof) # true
```

```
OSRProof: verified
  left:  Add(Power(Sin(x), 2), Power(Cos(x), 2))
    Add(Power(Sin(x), 2), Power(Cos(x), 2))  =  1   [1.1:1] Pythagorean Identity
    ⇒ 1
  right: 1
    ⇒ 1
  both sides reduce to 1
```

An equation written with `~` can be proved directly, and hypotheses are carried
into the proof:

```julia
prove(Add(Power(Sin(x), 2), Power(Cos(x), 2)) ~ 1, rules)
prove(Power(x, 0), 1, power_rules; assumptions=[IsNonzero(x)])
```

Both sides are normalised with the rule set and the normal forms are compared up
to a renaming of bound variables, so the search succeeds exactly when the two
sides are joinable. Each recorded step is local, which is what a rewrite tactic
in a proof assistant consumes; every OSR rule is an oriented instance of an
equation, so the steps on the right read backwards complete the derivation.

The search is sound but incomplete. A verified proof means every step is a rule
application whose constraints held where it fired. A failure means the rule set
offered no path, which is not a proof of inequivalence — a rule set that is not
confluent can fail to join two equivalent expressions — so the result reads
"not proved" rather than "unequal".

## Assumptions and Safe Rewrites

Rules carrying a predicate are applied only when it is established.  For
example, `NonzeroQ` is mapped to `is_nonzero`: it accepts a nonzero literal,
or a symbolic term explicitly declared nonzero.  This prevents the invalid
unconditional rewrite `0^0 = 1`.  Likewise, `NotEqual` does not infer a
mathematical inequality from two structurally different symbolic terms.

```julia
@syms x Power(a, b)
power_rules = @load_osr("path/to/1.1-basic-exponents.json")

simplify(Power(x, 0), power_rules)                         # unchanged
simplify(Power(x, 0), power_rules; assumptions=[IsNonzero(x)]) # 1
```

## Wildcards

A rule's pattern declares its wildcards; its result and its constraints refer to
the bindings the pattern made.

| Spelling | Meaning | Compiles to |
| --- | --- | --- |
| `~x` | slot | `~x` |
| `x_` | blank | `~x` |
| `x_integer` | typed blank | `~x::IntegerQ` |
| `xs__` | sequence of at least one expression | `~~xs`, guarded non-empty |
| `xs___` | sequence, possibly empty | `~~xs` |

A typed blank accepts the domains `integer`, `rational`, `real`, `complex`, and
`number`; any other domain is a rule-file error rather than a silently inert
rule.

OSR also spells an optional operand `a.`, as in RUBI's `(a_. + b_.*x_)^m_`.
Matching one requires knowing the identity element of the enclosing operation,
which `SymbolicUtils` provides only for the native `+`, `*`, and `^`, never for
the uninterpreted heads a rule file declares. The loader therefore rejects such
a wildcard instead of compiling it into a rule that could never fire.

## The constraint predicate library

A rule's `constraints` array is compiled into a Julia guard. Each entry names a
predicate and applies it to OSR expressions:

```json
"constraints": [
  ["FreeQ", "~m", "x"],
  ["Not", ["EqQ", "~m", -1]],
  ["Or", ["IntegerQ", "~m"], ["And", ["GtQ", "~a", 0], ["GtQ", "~c", 0]]]
]
```

`Not`, `And`, and `Or` are combinators: they nest constraints and compile to
Julia control flow, never to a symbolic `Not`/`And`/`Or` term. Every other
entry is a predicate application, and all entries of the array must hold.

The library implements the predicates below, covering 97% of the constraint
applications in the RUBI dataset:

| Group | Predicates |
| --- | --- |
| Comparison | `EqQ`, `NeQ`, `GtQ`, `LtQ`, `GeQ`, `LeQ` |
| Integer-qualified | `IntegerQ`, `IntegersQ`, `IGtQ`, `ILtQ`, `IGeQ`, `ILeQ` |
| Numeric domain | `RationalQ`, `FractionQ`, `HalfIntegerQ`, `PosQ`, `NegQ`, `FalseQ`, `NumericQ`, `RealQ`, `ComplexQ` |
| Structural | `FreeQ`, `AtomQ`, `SumQ`, `ProductQ`, `PowerQ`, `MemberQ` |
| Polynomial | `PolynomialQ`, `PolyQ`, `LinearQ`, `QuadraticQ` |

`GtQ`, `LtQ`, `GeQ`, and `LeQ` accept RUBI's chained form, so `GtQ(u, v, w)`
means `u > v > w`.

Every predicate is conservative: it answers `true` only when the property is
established, so an unproved guard leaves its rewrite unapplied rather than
risking an invalid one. A closed arithmetic expression is evaluated exactly,
which is what makes a guard such as `["PosQ", ["Power", 2, -1]]` decidable:

```julia
OpenSymbolicRules.osr_number(Power(2, -1)) # 1//2
```

Folding only recognises the canonical `Add`, `Multiply`, `Subtract`, `Divide`,
and `Power` heads. A rule file that renames them still loads, but its
arithmetic becomes opaque and its guarded rewrites stay inactive.

A predicate the library does not define is resolved in the module that loads
the rule file, so a host can supply its own:

```julia
module Host
    using OpenSymbolicRules
    EvenIntegerQ(value) = value isa Integer && iseven(value)
    const rules = @load_osr("path/to/rules.json") # may use ["EvenIntegerQ", "~m"]
end
```

## Symbolics.jl Interoperability

When Symbolics.jl is loaded, `to_osr` converts its differential operator into
the canonical OpenMath-aligned representation `Derivative(Lambda(x, f))`.
`to_symbolics` performs the inverse conversion, preserving the differentiation
variable and expression.

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

## Rule dispatch

`simplify` does not try every rule on every term. Rules are indexed by the
operation their pattern requires at the root of a term, so applying a rule set
costs one dictionary lookup rather than one matcher call per rule. On a
synthetic 6000-rule set this applies rules roughly 470 times faster than a
linear scan, which is what makes a catalogue the size of RUBI usable.

Three kinds of pattern have no root requirement and are therefore always tried:
a bare slot (`~a`), a slot in head position (`(~f)(~a)`), and a pattern holding
an optional slot (`(~a)^(~!b)`), which `SymbolicUtils` lets match a term that
lacks the operation entirely.

Dispatch is an optimisation, not a change of semantics: the rules that can match
are applied in their original order, exactly as a linear scan would.

## Binders and lexical scope

`Lambda`, `Forall`, and `Exists` introduce a lexical scope. Every other binding
construct — an integral, a sum, a product, a derivative — carries its bound
variable inside a `Lambda`, as the OpenMath `fns1#lambda` symbol prescribes, so
the Calculus profile writes a derivative as `Derivative(Lambda(x, body))`:

```julia
@syms x c
rules = @load_osr_profile("path/to/Calculus")

simplify(Derivative(Lambda(x, c)), rules)             # Lambda(x, 0)
simplify(Derivative(Lambda(x, Power(x, 2))), rules)   # Lambda(x, Multiply(2, Power(x, Add(2, -1))))
```

A bound occurrence is not an occurrence of the free variable, and `FreeQ`
respects that:

```julia
FreeQ(Lambda(x, Sin(x)), x) # true
free_variables(Lambda(x, Add(x, y))) # Set([:y])
```

`osr_substitute` substitutes for the free occurrences of a variable and is
capture-avoiding: a binder whose variable occurs free in the replacement is
alpha-renamed first, so the replacement keeps referring to the same variable it
did outside the binder.

```julia
osr_substitute(Lambda(y, Add(x, y)), x => y) # Lambda(y1, Add(y, y1))
```

Two expressions that differ only in the names of their bound variables are
compared with `alpha_equivalent`:

```julia
alpha_equivalent(Lambda(x, Sin(x)), Lambda(y, Sin(y))) # true
alpha_equivalent(Lambda(x, Sin(x)), Lambda(y, Sin(x))) # false
```

## Associativity and commutativity

Associativity and commutativity are properties of the OpenMath symbol a head is
bound to, never of the head's spelling. A rule file declares those bindings in
its `semantics` block, so the file below gets commutative matching for `Plus`
without having to be named `Add`:

```json
{
  "semantics": { "Plus": "openmath:arith1#plus" },
  "rules": [
    { "id": 1, "pattern": ["Plus", "~x", 0], "constraints": [], "result": "~x" }
  ]
}
```

An n-ary expression headed by an associative symbol (`arith1#plus`,
`arith1#times`, `logic1#and`, `logic1#or`, `logic1#xor`) is normalized to
left-associated binary SymbolicUtils terms at load time.

A pattern headed by a commutative symbol (`arith1#plus` and the Boolean
connectives `logic1#and`, `logic1#or`, `logic1#xor`, `logic1#xnor`,
`logic1#nand`, `logic1#nor`, `logic1#equivalent`) compiles to a
`SymbolicUtils.ACRule`, which matches every operand order with a single rule.
A rule file therefore never needs a mirrored copy of a commutative pattern:

```julia
simplify(Plus(x, 0), rules) # x
simplify(Plus(0, x), rules) # x
```

`arith1#times` is deliberately excluded. An OSR expression carries no shape
information, so a `times` operand may be a matrix and reordering it would be
unsound.

With Symbolics.jl, symbolic arrays can be declared with
`@variables A[1:m, 1:n]`. Matrix addition may use `Add` when dimensions are
compatible, but matrix multiplication must retain its operand order. A future
matrix profile will need explicit shape constraints and matrix-product
semantics rather than scalar `arith1#times` assumptions.

The same rule is stricter for tensors: addition is commutative only for equal
shapes, whereas tensor product, contraction, and axis permutation are ordered
operations. They must be represented by dedicated heads with explicit index
and shape metadata; they must never be silently encoded as `Multiply`.
