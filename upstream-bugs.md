# Upstream Bugs

This file tracks bugs discovered in upstream dependencies.

## SymbolicUtils.jl 4.46.6 — a failed rewrite discards its cause

**Observed with:** SymbolicUtils.jl 4.46.6, Julia 1.13.0, Linux x86_64.

`(r::Rule)(term)` in `src/rule.jl` wraps the whole match-and-build in a
`try`/`catch` and rethrows `RuleRewriteError(r, term)`, dropping the exception
that was actually raised:

```julia
try
    success(bindings, n) = n == 1 ? (rhs(assoc(bindings, :MATCH, term))) : nothing
    return r.matcher(success, (term,), EMPTY_IMMUTABLE_DICT)
catch err
    throw(RuleRewriteError(r, term))
end
```

`showerror` for `RuleRewriteError` then prints the entire rule and the term.
When a rule's result names something the loading module does not define, the
reported message is "Failed to apply rule <whole rule> on expression <term>"
and the underlying `UndefVarError` naming the missing head is lost.

**Why it matters here:** loading the RUBI corpus surfaces exactly this. Telling
"this rule needs `PolynomialRemainder`, which is not implemented" apart from
"this rule is wrong" requires the cause, and diagnosing a failure meant
re-running the matcher by hand outside the guard.

**Suggested fix:** attach the cause, for example
`throw(RuleRewriteError(r, term, err))`, and have `showerror` print it.

**Workaround:** `scripts/rubi_conformance.jl` applies rules one at a time so a
failure can at least be attributed to a named OSR rule.

## SymbolicUtils.jl 4.46.6 — `DefSlot` has no public constructor path for a non-native operation

**Observed with:** SymbolicUtils.jl 4.46.6, Julia 1.13.0, Linux x86_64.

`@rule`'s `~!x` spelling resolves an absent operand's default through
`defaultValOfCall`, which accepts only `:+`, `:*`, and `:^` and errors
otherwise. The matcher itself (`defslot_term_matcher_constructor`) is fully
general and never reads `DefSlot.op`, so any operation with an identity element
would work — but a rule written with `~!x` under an uninterpreted head cannot be
constructed.

**Why it matters here:** every OSR head is an uninterpreted symbol, so the
36,485 optional operands of the RUBI corpus cannot use `~!x` at all.

**Suggested fix:** let `~!x::predicate` take an explicit default, or resolve the
default through an overridable function rather than a hard-coded list.

**Workaround:** `_wildcard_to_expr` emits `$(DefSlot(name, alwaystrue, nothing,
default))` as an interpolation, which `makepattern` splices verbatim. This
relies on `DefSlot` being constructible, which is not a documented API.
