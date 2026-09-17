"""
    OSRProofStep(rule, before, after)

One licensed rewrite: `rule` turned the subterm `before` into `after`.  A step is
local, so it justifies the whole expression only together with congruence —
which is exactly how a rewrite tactic works in a proof assistant.
"""
struct OSRProofStep
    rule::Any
    before::Any
    after::Any
end

function Base.show(io::IO, step::OSRProofStep)
    print(io, step.before, "  =  ", step.after)
    step.rule === nothing && return
    print(io, "   [", step.rule, "]")
    description = step.rule isa OSRRule ? step.rule.description : nothing
    description === nothing || print(io, " ", description)
    return
end

"""
    OSRProof

The outcome of an equivalence check.  When `verified`, the two sides rewrite to
a common `normal_form` along `left_steps` and `right_steps`, under
`assumptions`.

Every OSR rule is an oriented instance of an equation, so the steps on the right
read backwards give a derivation of `right` from `normal_form`, and the two
chains together form a derivation of `left = right`.
"""
struct OSRProof
    verified::Bool
    left::Any
    right::Any
    left_normal_form::Any
    right_normal_form::Any
    normal_form::Any
    left_steps::Vector{OSRProofStep}
    right_steps::Vector{OSRProofStep}
    assumptions::Any
end

"""
    verified(proof)

Return whether a rewrite path between the two sides was found.

A verified proof is sound: every step is a rule application whose constraints
held where it fired.  An unverified one is not a disproof — the rule set may
simply lack the path — so the two sides are reported as unproved rather than
unequal.
"""
verified(proof::OSRProof) = proof.verified

function Base.show(io::IO, proof::OSRProof)
    println(io, "OSRProof: ", proof.verified ? "verified" : "not proved")
    if proof.assumptions !== nothing && !isempty(proof.assumptions)
        println(io, "  under ", join(string.(proof.assumptions), ", "))
    end

    println(io, "  left:  ", proof.left)
    for step in proof.left_steps
        println(io, "    ", step)
    end
    println(io, "    ⇒ ", proof.left_normal_form)

    println(io, "  right: ", proof.right)
    for step in proof.right_steps
        println(io, "    ", step)
    end
    println(io, "    ⇒ ", proof.right_normal_form)

    if proof.verified
        print(io, "  both sides reduce to ", proof.normal_form)
    else
        print(io, "  no rewrite path found; this is not a proof of inequivalence")
    end
    return
end

function _normalize_with_trace(expr, rules, assumptions)
    result, steps = simplify(expr, rules; mode=:trace, assumptions)
    return result, [OSRProofStep(step.rule, step.before, step.after) for step in steps]
end

"""
    prove(left, right, rules; assumptions=nothing)
    prove(equation, rules; assumptions=nothing)

Search for a rewrite path between two expressions and return the
[`OSRProof`](@ref) that records it.

Both sides are normalised with `rules` and the normal forms are compared up to a
renaming of bound variables, so the search succeeds exactly when the two sides
are joinable by the rule set.  This is sound but incomplete: a rule set that is
not confluent may fail to join two equivalent expressions, which is why a
failure is reported as unproved rather than as a disproof.

```julia
@syms x
rules = @load_osr_profile("path/to/Trigonometry")
proof = prove(Add(Power(Sin(x), 2), Power(Cos(x), 2)), 1, rules)
verified(proof) # true
```
"""
function prove(left, right, rules::AbstractVector; assumptions=nothing)
    left_normal_form, left_steps = _normalize_with_trace(left, rules, assumptions)
    right_normal_form, right_steps = _normalize_with_trace(right, rules, assumptions)
    joined = alpha_equivalent(left_normal_form, right_normal_form)
    return OSRProof(
        joined, left, right,
        left_normal_form, right_normal_form,
        joined ? left_normal_form : nothing,
        left_steps, right_steps, assumptions,
    )
end

prove(equation::Equation, rules::AbstractVector; assumptions=nothing) =
    prove(equation.lhs, equation.rhs, rules; assumptions)

export OSRProof, OSRProofStep, prove, verified
