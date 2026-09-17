# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
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
