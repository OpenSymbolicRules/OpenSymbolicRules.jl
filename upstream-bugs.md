# Upstream Bugs

This file tracks bugs discovered in upstream dependencies.

## Integration rule identities are not globally unique

- **Upstream project:** `OpenSymbolicRules/Integration`
- **Observed with:** Integration checkout beside this package on 2026-09-17;
  OpenSymbolicRules.jl 0.1.0 on Julia 1.13.
- **Reproduction:** evaluate
  `@load_osr_profile("../Integration")` from this package.
- **Actual result:** loading stops at duplicate canonical identity `1.1.2:1`.
  For example, both
  `rules/1-algebraic/1.1-binomial/1.1.2-quadratic/1.1.2.x-P(x)-(a+b-x^2)^p.json`
  and
  `rules/1-algebraic/1.1-binomial/1.1.2-quadratic/1.1.2.y-P(x)-(c-x)^m-(a+b-x^2)^p.json`
  declare `section: "1.1.2"` and a rule with `id: 1`.
- **Expected result:** every rule must have a unique `section:id` identity across
  a loadable profile, as required for stable trace and proof references.
- **Suggested upstream fix:** give each leaf file a distinct `section` value
  (for example `1.1.2.x` and `1.1.2.y`) or renumber its rule IDs within the
  shared section.
