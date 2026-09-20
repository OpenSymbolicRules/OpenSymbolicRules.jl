# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `EqQ` and `NeQ` decide a polynomial identity exactly, through the sparse
  rational core: a difference that is the zero polynomial proves equality, one
  that is a nonzero constant proves inequality, and one that still mentions a
  symbol proves neither. Nothing leaves ℚ.
- `BinomialQ` and `BinomialMatchQ`, recognising `a + b*x^n` with `a`, `b`, and
  the exponent free of `x`, optionally of a given exponent. Both read the
  written shape, so they decline some expressions RUBI would accept rather than
  risk an invalid rewrite.
- `LinearMatchQ`, which asks whether an expression is already written as
  `a + b*x` rather than merely having degree one. RUBI's normalization rules are
  guarded by the difference between the two.
- The exact polynomial core reads the canonical OSR heads `Add`, `Multiply`,
  `Subtract`, and `Power` alongside the native operators, and accepts a closed
  arithmetic expression such as `Power(2, -1)` as a coefficient.
- `record_withheld!`, `withheld_predicates_seen`, and `reset_withheld!`, which
  record — on request — the predicates that decide a guard against its rule, so
  a measurement can say which predicate held a rule back.
- `unproved_predicates_seen` and `reset_unproved!`, which record the predicates
  that abandoned a guard. A rule that does not fire says nothing about why on
  its own, and this is what tells a guard that is false apart from one that
  could not be decided.
- The conformance report counts unsolved problems against the predicate that
  blocked a rule covering them, so "implementing this predicate would unblock
  these problems" becomes a measurement.
- The conformance report now lists the constraint predicates with no
  implementation, ranked by the number of rule guards each holds back. A rule
  gated by one is loaded and never fires, so it is invisible in the outcome
  counts.
- `UnprovedConstraint`: a constraint predicate that neither this package nor the
  loading module resolves abandons its guard instead of raising an
  undefined-variable error, so the rule does not fire and the rule set keeps
  going. Abandoning rather than answering `false` keeps `Not` honest, and the
  short-circuit of `&&` and `||` keeps `Or(p, undecidable)` established when `p`
  is.
- Exact folding of closed arithmetic in the conformance report's comparison, so
  a correct `x^(3+1)/(3+1)` is not reported as wrong against a recorded `x^4/4`.
- A `symbol` typed wildcard (`x_symbol`) and its `is_symbol` predicate, matching
  a variable and nothing else. A rule that binds a variable of the problem is
  valid only when that operand really is a variable.
- Uninterpreted heads: an operator a rule file declares an OpenMath symbol for
  but this package does not implement is now declared as a symbolic function in
  the loading module, so the rule produces an unevaluated term instead of
  raising an undefined-variable error the moment it fires.
- `scripts/rubi_conformance.jl` (`just conformance <section>`), which applies
  the rule set to every RUBI test problem of a section and reports `verified`,
  `closed form`, `unevaluated`, `unchanged`, and `error` separately, so coverage
  is never reported as correctness.
- Bare-name references to a rule's bindings: a pattern declares a wildcard as
  `m_` or `m.`, and its result and constraints refer to it as `m`, which is how
  the RUBI dataset is written. A name the pattern never bound stays a free
  symbol.
- Optional operand wildcards (`a.`, `m.3`): the enclosing operation supplies the
  identity element an absent operand binds to, so a single rule covers every
  degenerate shape of a RUBI pattern such as `(a. + b.*x)^m.`.
- Pattern variables in operator position, so one rule matches a whole family of
  heads; such a head names a binding and needs no OpenMath symbol.
- `If` as a constraint combinator, compiling to Julia control flow over booleans
  rather than to a symbolic term.
- `Condition` as the guarded-pattern form of the rule language, pairing a
  pattern with the test that admits it, as `MatchQ` uses it.
- A structured SAT operation API with `SATProblem`, `solve`, selectable
  backends, and explicit satisfiable, unsatisfiable, or unknown results.
- Integration with the lightweight MIT-licensed `CommonSolve.jl` interface, so
  CAS solver backends extend the ecosystem-standard `solve` function.
- A CommonSolve `init`/`solve!` state for the pure-Julia SAT backend.
- Structured `SMTProblem` support for built-in exact rational linear arithmetic
  and ground equality theories through the CommonSolve interface.
- Structured mixed rational SMT results through the CommonSolve interface,
  combining exact linear constraints with equality and disequality atoms over
  rational variables.
- An exact pure-Julia univariate Sylvester resultant over the sparse rational
  polynomial core.
- Exact univariate polynomial discriminants over the sparse rational core,
  including repeated-root detection through the derivative resultant.
- Exact univariate square-free decomposition with monic factors and explicit
  multiplicities over the rational polynomial core.
- Exact rational-root extraction for univariate polynomials, returning only
  provable rational roots and their multiplicities.
- Bounded exact normalization of numeric square roots, preserving OpenMath
  radical semantics without introducing floating-point literals.
- A structured CommonSolve operation for exact univariate polynomial roots,
  including a residual polynomial and an explicit completeness flag.
- `solve(equation, variable)` for exact univariate rational-polynomial
  equations, preserving unresolved algebraic factors in the structured result.
- An optional OpenMath.jl extension which round-trips core arithmetic and
  propositional-logic OSR/SymbolicUtils expressions, exact rational literals,
  canonical lambda-bound derivatives, and ordered piecewise branches through
  typed OpenMath objects; OSR collections use `list1#list`, never the linear
  algebra `linalg2#vector` symbol; canonical limits retain their point,
  approach, and lambda-bound expression.
- Exact OpenMath round trips for the universal constants `π`, `e`, and `i`,
  preserving their Content Dictionary identities instead of approximating them.
- OpenMath round trips for the complete built-in trigonometric, inverse
  trigonometric, hyperbolic, and inverse hyperbolic head families.
- OpenMath round trips for strict symbolic relations, allowing conditional
  piecewise branches to preserve `relation1#gt` and `relation1#lt` semantics.
- A dependency-free, pure-Julia DPLL SAT kernel for CNF constraints, as the
  Boolean foundation for future DPLL(T) theory solving.
- Exact rational linear-constraint feasibility by Fourier--Motzkin
  elimination, including strict inequalities and equality.
- A pure-Julia DPLL(T) entry point combining CNF Boolean search with exact
  rational linear theory atoms.
- Exact branching for negated linear equalities in the DPLL(T) solver.
- Ground equality and disequality theory with pure-Julia union-find propagation
  and a dedicated DPLL(T) entry point.
- Checkable Boolean model witnesses for satisfiable CNF problems.
- Exact rational model reconstruction for satisfiable linear theory problems.
- Combined Boolean and rational model witnesses for linear DPLL(T) problems.
- Equivalence-class and combined Boolean/equality model witnesses for ground
  equality DPLL(T) problems.
- A sort-explicit rational SMT entry point combining variable equalities,
  disequalities, and exact linear arithmetic.
- Conservative exact consistency checks for CAS sign and bound assumptions.
- Exact interval-membership bounds in rational assumption consistency checks.
- Exact DPLL(T) handling of nonzero assumptions in the rational fragment.
- Rejection of `simplify` calls whose supplied rational assumptions are proven
  contradictory.
- Combined rational-hypothesis entailment for conditional predicates.
- Exact sparse multivariate polynomial normal forms over rational coefficients,
  including `:lex`, `:grlex`, and `:grevlex` orders, S-polynomials,
  Buchberger bases, and ideal-membership checks.
- Explicit, exact conversion between `SymbolicUtils` expressions and sparse
  polynomials, with rejection of non-polynomial expressions.
- A roadmap for opt-in domain modules: `Core`, `Algebra`, `Calculus`,
  `Trigonometry`, `Integration`, and `Logic`, with `Integration` covering both
  integral representations and procedural/rule-based integration backends.
- Roadmap requirements for explicit operation-result status and structured,
  serializable operation traces with configurable detail and renderers.
- Roadmap coverage for canonical symbolic rendering, including parentheses,
  rational-unit normalization, and redundant-sign elimination.
- Built-in symbolic heads for the current OpenMath Calculus profile and an
  end-to-end profile-loading test against the real Calculus repository.
- Canonical `identity:id` rule names and source provenance on loaded
  `OSRRule` values, exposing specification-level traceability in rewrite
  traces.
- Initial project scaffolding using BestieTemplate.jl
- Setup Documenter.jl and testing framework
- GitHub Actions validation of bundled OSR rule fixtures against the specification schemas.
- Ordered rewrite-profile loading and structured multi-premise inference-profile loading.
- OSR v0.1 trailing-underscore wildcards and lexical `Forall`/`Exists` binders in the JSON parser.
- Named `OSRRule` values and an `on_step` callback for observable rewriting without library output.
- A roadmap for shape- and index-aware matrix and tensor algebra.
- Roadmap entries for binders, piecewise expressions, symbolic sets, units,
  noncommutative algebra, discrete operators, distributions, and coefficient
  domains.
- Support for the OSR `NonzeroQ` constraint predicate, including explicit
  symbolic `IsNonzero` assumptions.
- First-order quantifier rewrites with sequence captures (`xs__`) that
  preserve one or more bound variables.
- A Symbolics.jl bridge for canonical `Derivative(Lambda(variable, expression))`
  terms.
- A standard library of OSR constraint predicates covering 97% of the
  constraint applications in the RUBI dataset: the comparison predicates
  `EqQ`, `NeQ`, `GtQ`, `LtQ`, `GeQ`, and `LeQ` including RUBI's chained form,
  the integer-qualified `IntegerQ`, `IntegersQ`, `IGtQ`, `ILtQ`, `IGeQ`, and
  `ILeQ`, the numeric-domain `RationalQ`, `FractionQ`, `HalfIntegerQ`, `PosQ`,
  `NegQ`, and `FalseQ`, the structural `AtomQ`, `SumQ`, `ProductQ`, `PowerQ`,
  and `MemberQ`, and the polynomial `PolynomialQ`, `PolyQ`, `LinearQ`, and
  `QuadraticQ`.
- `Not`, `And`, and `Or` constraint combinators, compiled to Julia control flow
  so that nested constraints guard a rewrite instead of building a symbolic
  logic term.
- `osr_number` and `osr_degree`, which evaluate a closed OSR arithmetic
  expression exactly and measure the degree of an OSR polynomial.
- OSR `List` expressions, compiled to Julia vectors.
- Lexical scope for the `Lambda`, `Forall`, and `Exists` binders:
  `bound_variables`, `binder_body`, `free_variables`, and `occurs_free`.
- `osr_substitute`, a capture-avoiding substitution that alpha-renames a binder
  whose variable occurs free in the replacement.
- `alpha_equivalent`, comparing two expressions up to a consistent renaming of
  their bound variables.
- A `PrecompileTools.jl` workload covering the matcher, the dispatcher, the
  rewriter, and the scope and proof helpers, which cuts the time to a first
  `simplify`, `trace`, and `prove` from about 1.5 s to about 0.8 s.
- `entailed`, which decides a property of a term from the hypotheses in scope by
  what their domains imply rather than by a literal match, so `x ∈ 2..5` proves
  positivity, nonzeroness, and realness at once.
- `normalize_fact`, which reads a host's own membership hypothesis as an OSR
  fact; the Symbolics extension uses it for `Symbolics.VarDomainPairing`.
- `Piecewise`, `Piece`, and `Otherwise` heads bound to the OpenMath `piece1`
  content dictionary, with `piecewise_pieces` to read the branches,
  `decide_condition` for the three-valued judgement of a condition, and
  `select_piece` to reduce a piecewise once the applicable branch is settled.
- `osr_collection`, which reads the elements of a collection expression whether
  `SymbolicUtils` kept it as a literal vector or wrapped it in an array literal.
- `prove`, an equivalence verifier that searches for a rewrite path between two
  expressions and returns an `OSRProof` recording the steps, the common normal
  form, and the hypotheses it was established under.  The search is sound but
  incomplete, so a failure is reported as unproved rather than as a disproof.
- `OSRDispatch`, a head-indexed rewriter that selects the applicable rules with
  one dictionary lookup instead of one matcher call per rule.  `simplify` and
  `build_simplifier` now use it; on a synthetic 6000-rule set it applies rules
  roughly 470 times faster than a linear `Chain`.

### Changed
- The conformance report applies the rule set first-match-wins, as an ordered
  integration rule set is meant to be read: the rules after the one that fires
  are alternatives for the same integral, not further steps. Continuing where a
  rule reduces one integral to another stays the job of the recursion that
  follows the remaining `Int`.
- `OSRDispatch` now indexes a rule by the operation at the root of its pattern
  *and* the one at its first operand. Restoring RUBI's `Int[integrand, x]`
  wrapper made every rule of the corpus share the head `Int`, so the root alone
  selected the whole set for every integral. Over section 1.1.1, 183 of 186
  rules carry an operand key and a power integrand now tries 7 rules instead of
  186. An associative-commutative rule keeps no operand key, since its matcher
  tries every operand order.
- An operator is never resolved to a Julia binding that cannot act as an
  operation. `Int` names an indefinite integral in the RUBI corpus and a machine
  integer in `Base`; a head that would resolve to a type is registered in
  `OpenSymbolicRules.UninterpretedHeads` instead. Uninterpreted heads now live
  there rather than in the loading module, so loading a rule file introduces no
  name into the caller's scope.
- Head dispatch stays selective when a pattern carries an optional operand
  below its root. `SymbolicUtils` builds a default-valued matcher only where a
  `DefSlot` is a direct argument, so `Int((a. + b.*x)^m., x)` still requires an
  `Int`; treating any nested optional slot as head-dissolving would have put
  the whole RUBI set into the always-try bucket.
- Require an OpenMath declaration only for mathematical operators. A structural
  head of the expression language (`List`, `Condition`) and a wildcard in
  operator position carry no domain meaning, so a rule file no longer has to
  rebind them. This raises the Integration dataset from 13 to 151 of its 188
  rule files at semantic-validation time, without weakening the closure check
  the domain repositories run.
- Make `NotEqual` conservative for symbolic terms, preventing guarded rules
  from treating an unproved symbolic inequality as true.
- Mapped bundled fixture operators to canonical OpenMath Content Dictionary identifiers.
- Kept `simplify` as the sole public simplification API; removed the stale,
  undefined `osr_simplify` export.
- Updated the usage tutorial to use canonical OpenMath-aligned `Power` and
  `Multiply` heads with a complete Algebra profile.
- Reject duplicate canonical rule identities while compiling a rewrite profile.
- Validate the OpenMath semantic declaration of every mathematical operator at
  rule-load time.
- Export canonical OpenMath logic and quantifier heads for direct profile use.
- Normalize canonical n-ary OpenMath associative expressions to binary
  SymbolicUtils terms while loading rules.
- Compile commutative rule patterns to a single `SymbolicUtils.ACRule` instead
  of a mirrored copy per operand order.  Commutative and associative
  connectives (`xor`, `xnor`, `nand`, `nor`, `equivalent`) are now matched in
  any operand order too, while the order of possibly matrix-valued
  `arith1#times` operands is preserved.
- Derive associativity and commutativity from the OpenMath symbol a head is
  bound to in a rule file's `semantics` block, rather than from the head's
  spelling, so a rule file may name its heads freely.
- Decide `is_integer`, `is_numeric`, `is_positive`, `is_negative`,
  `is_nonzero`, `is_real`, and `is_complex` by evaluating a closed arithmetic
  expression, so a guard spelled as `["PositiveQ", ["Power", 2, -1]]` no longer
  blocks its rewrite.
- Resolve a predicate the library defines inside the library itself, so a rule
  file can no longer reach an unrelated name of the loading module by accident;
  an unknown predicate is still resolved in that module as a host extension
  point.

### Fixed
- `PolynomialQ`, `PolyQ`, `LinearQ`, and `QuadraticQ` now read a collection the
  way `FreeQ` does: `LinearQ[{u, v}, x]` asks whether every element is linear
  in `x`. Reading the list as a single expression made the guard decline a rule
  that plainly applied; the RUBI corpus writes 41 guards that way.
- Answer `FreeQ` correctly when either side is a collection.  A quantifier binds
  a list, and asking whether a body was free of that list compared the body to
  the list itself, so `FreeQ(Sin(x), [:x])` reported that `Sin(x)` is free of
  `x`.  RUBI's `FreeQ[{a, b, m}, x]` spelling is accepted on the other side.
- Decide `is_real` and `is_complex` for a symbolic argument.  Both referred to
  `Reals()` and `ComplexPlane()`, which `DomainSets.jl` does not define, so any
  rule constrained by `RealQ` or `ComplexQ` raised an `UndefVarError` instead of
  answering.
- Stop treating `x ∈ 0..Inf` and `x ∈ HalfLine()` as proofs of positivity.  Both
  domains are closed at zero and so contain it.
- Accept a `NegativeHalfLine` or a `RealLine` in `x ∈ domain`, which previously
  raised a method ambiguity.
- Read a hypothesis written with Symbolics' `∈` operator.  Once `Symbolics.jl`
  was loaded its method won, and the resulting `VarDomainPairing` silently
  constrained nothing.
- Traverse collection arguments in `free_variables`, `occurs_free`,
  `osr_substitute`, and `alpha_equivalent`.  A branch or element list was
  invisible to scope analysis, so its variables were reported as neither free
  nor substitutable.
- Accept any operand on the `Lambda`, `Derivative`, `Integral`, `Limit`, and
  `Piecewise` heads.  Typing them as `Number` rejected a lambda over a
  proposition or a piecewise, which are well-formed OSR terms.
- Compile every OSR v0.1 wildcard spelling.  `xs__`, `xs___`, and a typed blank
  such as `m_integer` were each read as an ordinary symbol, silently producing a
  rule that could never fire; they now compile to the sequence and guarded slot
  patterns they denote.
- Reject the OSR optional wildcard `a.` with a diagnostic instead of reading it
  as a symbol named `a.`.  Matching an optional operand requires the identity
  element of the enclosing operation, which `SymbolicUtils` provides only for
  the native `+`, `*`, and `^`.
- Conjoin three or more constraints correctly.  A rule with more than two
  constraints previously compiled to an invalid `&&` expression.
- Respect binders in `FreeQ`.  A bound occurrence is not an occurrence of the
  free variable, so `Lambda(x, Sin(x))` is now correctly reported free of `x`.
