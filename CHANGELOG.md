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
