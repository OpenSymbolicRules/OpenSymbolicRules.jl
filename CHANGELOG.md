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
- Match binary canonical `Add`, `And`, and `Or` rule patterns in either
  operand order, while preserving the order of possibly matrix-valued
  `Multiply` operands.
