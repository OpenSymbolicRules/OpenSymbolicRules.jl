# OpenSymbolicRules.jl

Documentation for [OpenSymbolicRules.jl](https://github.com/OpenSymbolicRules/OpenSymbolicRules.jl).

**OpenSymbolicRules.jl** is a zero-overhead, highly pedagogical rule engine client for the language-agnostic [Open Symbolic Rules](https://github.com/OpenSymbolicRules/OpenSymbolicRules.jl) JSON format. It integrates directly with `SymbolicUtils.jl` to provide both blazingly fast simplifications and step-by-step educational tracing.

## Features
- **AOT Compilation:** Parses JSON rules at macro expansion time (`@load_osr`) to emit pure Julia code with zero runtime overhead.
- **Unified Engine:** Combines rules from different domains (Algebra, Trigonometry, Calculus) into a single rewrite engine.
- **Pedagogical Tracer:** Includes an interactive `mode=:trace` and `mode=:verbose` to intercept and explain every mathematical operation applied to an expression.
