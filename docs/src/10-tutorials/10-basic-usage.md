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

Rules loaded from JSON retain their stable OSR name (`identity:id`) and their
description. For streaming output, logging, or a graphical interface, pass a
callback instead of relying on the library to print:

```julia
simplify(expr, alg_rules; on_step=step -> @info "rewrite" rule=step.rule.name)
```

## Loading an OSR rule-set profile

`@load_osr_profile` compiles the ordered manifest of a rule-set repository.
The repository can be a sibling checkout of this package or any local clone
with a `rules/meta.json` manifest:

```julia
calculus_rules = @load_osr_profile("../../Calculus")
```

The package provides the OpenMath heads used by the current Calculus profile,
including circular, hyperbolic, and inverse functions. No caller-side symbolic
declarations are required merely to load that profile.

## Piecewise expressions

A rewrite that is only valid on part of a domain keeps its validity conditions
instead of discarding them. `Piecewise` holds a list of branches, each a `Piece`
carrying a value and its condition, optionally closed by an `Otherwise`:

```json
["Piecewise", ["List",
  ["Piece", "x_", ["IsPositive", "x_"]],
  ["Otherwise", ["Multiply", -1, "x_"]]
]]
```

```julia
@syms x
absolute = Piecewise([Piece(x, IsPositive(x)), Otherwise(Multiply(-1, x))])
piecewise_pieces(absolute) # the branches, with `nothing` as the Otherwise condition
```

`select_piece` reduces a piecewise to the value of the branch that applies.
Branches are examined in order, and a branch is taken once its condition is
decided true and every earlier one is decided false. An undecided condition
stops the search, because a later branch may not overtake one that might yet
apply:

```julia
select_piece(absolute)                                  # unchanged: nothing is known about x
assuming(IsPositive(x)) do select_piece(absolute) end   # x
```

`decide_condition` is the three-valued judgement behind it: `true`, `false`, or
`nothing` when undecided. A condition is decided when it is a Boolean literal,
when it is a relation over closed arithmetic expressions, or when it is an
active hypothesis; `And`, `Or`, and `Not` combine those answers, so a
conjunction with one false operand is false even when the other is unknown.

A symbolic predicate answering `false` means "not proved", which is why an
unproved condition leaves the piecewise intact rather than skipping the branch.

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

### What a hypothesis establishes

A hypothesis proves every property its domain implies, not only the one it was
written as. Membership can be declared with a `DomainSets.jl` domain, an
`IntervalSets.jl` interval, or a Julia type:

```julia
assuming(x ∈ 2..5) do
    is_positive(x) # true
    is_nonzero(x)  # true
    is_real(x)     # true
    is_integer(x)  # false — an interval of reals proves nothing about integrality
end

assuming(x ∈ Integers()) do
    is_integer(x) # true
    is_real(x)    # true
end
```

A bound at zero only excludes zero when it is open, so `x ∈ 0..Inf` is not a
proof of positivity while `x ∈ OpenInterval(0, Inf)` is. The relational
hypotheses `IsPositive`, `IsNegative`, `IsNonzero`, `IsInteger`, `GreaterThan`,
and `LessThan` work the same way: `GreaterThan(x, 5)` proves positivity,
`GreaterThan(x, -3)` only proves that `x` is real.

Each hypothesis is weighed on its own, so the context is sound but does not
combine two hypotheses into a third: `x ∈ ℤ` proves integrality and `x > 0`
proves positivity, yet neither alone proves that `x` is a positive integer.

When `Symbolics.jl` is loaded, its `∈` builds a `VarDomainPairing` instead of
the package's `ElementOf`. Such a hypothesis is read as an OSR fact on entry, so
`assuming(x ∈ 2..5)` behaves the same either way.

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

`FreeQ` accepts a collection on either side. A quantifier binds a list, so a
side condition about its scope can ask about the whole binder, and RUBI's
`FreeQ[{a, b, m}, x]` spelling asks about every element of a list.
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

## OpenMath Interoperability

Loading the optional `OpenMath.jl` package activates an extension that exports
core arithmetic and propositional-logic expressions as typed OpenMath objects.
It uses Content Dictionary symbols, so the representation can then be
validated or written using OpenMath's XML, JSON, MathML, or binary encodings.

```julia
using OpenMath
using OpenSymbolicRules
using SymbolicUtils

@syms x
object = OpenSymbolicRules.to_openmath(Add(x, 3 // 2))
# OMA(OMS(arith1#plus), OMV(x), OMA(OMS(nums1#rational), OMI(3), OMI(2)))

expression = OpenSymbolicRules.from_openmath(object)
# Add(x, 3//2)

derivative = OpenSymbolicRules.to_openmath(Derivative(Lambda(x, Power(x, 2))))
# OMA(OMS(calculus1#diff), OMBIND(OMS(fns1#lambda), [x], ...))

piecewise = OpenSymbolicRules.to_openmath(
    Piecewise([Piece(x, GreaterThan(x, 0)), Otherwise(0)]))
# OMA(OMS(piece1#piecewise), OMA(OMS(piece1#piece), ...), OMA(OMS(piece1#otherwise), OMI(0)))

collection = OpenSymbolicRules.to_openmath([x, 1, Sin(x)])
# OMA(OMS(list1#list), OMV(x), OMI(1), OMA(OMS(transc1#sin), OMV(x)))

limit = OpenSymbolicRules.to_openmath(
    Limit(0, BothSides, Lambda(x, Divide(Sin(x), x))))
# OMA(OMS(limit1#limit), OMI(0), OMS(limit1#both_sides), OMBIND(...))

OpenSymbolicRules.to_openmath(π)
# OMS(nums1#pi)
```

The extension is deliberately optional and only runs at interchange
boundaries; OSR rewriting does not depend on OpenMath.jl.  It currently covers
core arithmetic, trigonometric and hyperbolic, exponential, propositional-logic,
canonical lambda-bound derivative, ordered piecewise, and structural list
heads, plus canonical limits. Unsupported
OpenMath symbols or OSR heads raise an explicit error,
which prevents silently assigning incorrect semantics.

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

## Exact polynomial normal forms

`SparsePolynomial` is an opt-in exact backend for algorithms over
multivariate polynomials with rational coefficients. It is intentionally
separate from general symbolic expressions: callers supply the polynomial ring
variables and its sparse monomial map explicitly.

```julia
p = SparsePolynomial([:x, :y], Dict((2, 0) => 1, (0, 1) => 1)) # x² + y
q = SparsePolynomial([:x, :y], Dict((1, 1) => 1, (0, 0) => -1)) # xy - 1

# Exact univariate elimination invariant
resultant(SparsePolynomial([:x], Dict((2,) => 1, (0,) => -1)),
          SparsePolynomial([:x], Dict((1,) => 1, (0,) => -2))) # 3//1

spoly(p, q; ordering=:lex)              # y² + x
normal_form(p, [q]; ordering=:grevlex)  # normal form modulo q
g = groebner_basis([p, q]; ordering=:lex)
ideal_membership(p, g; ordering=:lex)   # true
```

The available orders are `:lex`, `:grlex`, and `:grevlex`. This foundation is
for exact algebraic algorithms; conversion from `SymbolicUtils` expressions
and equation solving remain separate planned layers. For implementation
inspection, low-level leading-term and S-polynomial primitives stay qualified
as `OpenSymbolicRules.leading_monomial` and `OpenSymbolicRules.spoly`.

An explicit boundary retains the exact coefficient domain when exchanging
polynomials with `SymbolicUtils`. The requested variables define the ring;
functions, negative powers, and undeclared parameters are rejected.

```julia
using SymbolicUtils
@syms x y

p = to_sparse_polynomial(x^2 * y + 3 // 2, [:x, :y])
to_symbolic_polynomial(p, Dict(:x => x, :y => y))
```

## Propositional satisfiability

The Boolean kernel includes a small pure-Julia DPLL solver for finite CNF
problems. It has no native-library or solver-package dependency. Clauses use
the standard DIMACS literal convention: a positive integer denotes a variable,
and its negative denotes the variable's negation.

```julia
# (a ∨ b) ∧ (¬a ∨ b) ∧ (a ∨ ¬b)
satisfiable([[1, 2], [-1, 2], [1, -2]]) # true

# a ∧ ¬a
satisfiable([[1], [-1]])                # false
```

The structured operation API keeps solver selection and result status explicit:

```julia
result = solve(SATProblem([[1, 2], [-1, 2]]))
result isa SatResult # true
result.model          # directly checkable witness
```

This is the Boolean component of a planned pure-Julia DPLL(T) architecture.
Theory reasoning, such as equality and rational linear arithmetic, is added
only when its result can retain explicit assumptions and proof obligations.

For a satisfiable CNF problem, `sat_model` returns a dictionary that witnesses
the decision and can be checked directly against every clause. It returns
`nothing` for an unsatisfiable formula.

```julia
sat_model([[1, 2], [-1, 2]]) # Dict(1 => true, 2 => true)
```

### Exact rational linear theory

`linear_satisfiable` decides a conjunction of linear constraints over ℚ using
exact Fourier--Motzkin elimination. A constraint uses `:le`, `:lt`, or `:eq`
for ≤, <, or = respectively.

```julia
x_at_least_one = LinearConstraint(Dict(:x => -1), :le, -1)
x_less_than_one = LinearConstraint(Dict(:x => 1), :lt, 1)

linear_satisfiable([x_at_least_one, x_less_than_one]) # false
```

It is the exact rational theory component used by the DPLL(T) integration
below.

For a feasible system, `linear_model` reconstructs rational variable values
from the elimination layers. Its result is an ordinary dictionary and can be
checked against the original constraints without numerical tolerances.

```julia
linear_model([x_at_least_one]) # Dict(:x => 1)
```

### Combining Boolean and linear constraints

`linear_smt_satisfiable` now joins the local DPLL engine to linear theory
atoms. CNF clauses refer to positive atom numbers; a negative literal is the
exact logical negation of a non-strict or strict inequality.

```julia
atoms = Dict(
    1 => LinearConstraint(Dict(:x => 1), :le, 0),
    2 => LinearConstraint(Dict(:x => -1), :lt, -1), # x > 1
)

linear_smt_satisfiable([[1, 2]], atoms) # x ≤ 0 ∨ x > 1; true
linear_smt_satisfiable([[1], [2]], atoms) # false
```

`linear_smt_model` returns both the Boolean choices and the rational assignment
for the selected theory branch.

```julia
model = linear_smt_model([[1, 2]], atoms)
model.booleans
model.rationals
```

Negated equalities are expanded exactly as `a < b ∨ a > b`; the solver keeps
those alternatives as explicit theory branches. Proof-producing explanations
remain the next SMT milestone.

### Equality theory

For ground, uninterpreted symbols, `smt_satisfiable` uses union-find to close
equalities transitively before checking disequalities.

```julia
atoms = Dict(
    1 => EqualityConstraint(:a, :b, :eq),
    2 => EqualityConstraint(:a, :b, :ne),
)

smt_satisfiable([[1, 2]], atoms) # true
smt_satisfiable([[1], [2]], atoms) # false
```

`smt_model` returns the Boolean choices and a map from every ground term to its
equivalence-class representative.

```julia
model = smt_model([[1, 2]], atoms)
model.classes[:a] == model.classes[:b]
```

This equality theory is separate from rational linear arithmetic for now.
For symbols interpreted as rational variables, use the explicitly sorted
`rational_smt_satisfiable` entry point instead: it combines equality,
disequality, and linear arithmetic by translating `x = y` into `x - y = 0`.
It is intentionally distinct from the uninterpreted equality solver above.

```julia
numeric_atoms = Dict{Int,Union{LinearConstraint,EqualityConstraint}}(
    1 => EqualityConstraint(:x, :y, :eq),
    2 => LinearConstraint(Dict(:x => 1), :le, 0),
    3 => LinearConstraint(Dict(:y => -1), :le, -1),
)

rational_smt_satisfiable([[1], [2], [3]], numeric_atoms) # false
```

## Checking assumption consistency

The same exact rational engine can reject contradictory CAS hypotheses before
they are used to justify a conditional rewrite. It reports `nothing` rather
than guessing when a fact is outside its supported fragment.

```julia
@syms x
rational_assumptions_satisfiable([GreaterThan(x, 0), LessThan(x, 0)]) # false
rational_assumptions_satisfiable([IsNonzero(x), x ∈ 0..0]) # false
```

Exact interval memberships participate in the same check, including open and
closed endpoints.

```julia
rational_assumptions_satisfiable([x ∈ 1..2, LessThan(x, 1)]) # false
```

`simplify` performs this consistency check for supplied assumptions. A context
proven contradictory raises `ArgumentError`; an unsupported fact remains
conservative and does not block rewriting.

Supported facts can also combine to discharge a conditional predicate. For
example, neither `x ∈ [0,2]` nor `x ≠ 0` alone proves positivity, while their
combination does.

```julia
assuming(x ∈ 0..2, IsNonzero(x)) do
    is_positive(x) # true
end
```
