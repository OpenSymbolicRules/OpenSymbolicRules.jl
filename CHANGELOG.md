# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
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
- Conjoin three or more constraints correctly.  A rule with more than two
  constraints previously compiled to an invalid `&&` expression.
- Respect binders in `FreeQ`.  A bound occurrence is not an occurrence of the
  free variable, so `Lambda(x, Sin(x))` is now correctly reported free of `x`.
