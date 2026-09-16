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

### Changed
- Mapped bundled fixture operators to canonical OpenMath Content Dictionary identifiers.
- Kept `simplify` as the sole public simplification API; removed the stale,
  undefined `osr_simplify` export.
