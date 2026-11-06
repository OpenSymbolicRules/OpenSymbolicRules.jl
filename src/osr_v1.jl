"""
    OSRv1

Consumer of the OSR v1 interchange format produced by the Lean-native OSR core
(`OpenSymbolicRules/Lean`).  Expressions are OpenMath objects in the
OpenMath 2.0 JSON encoding, restricted to symbols (`OMS`), variables (`OMV`),
integers (`OMI`) and applications of a symbol (`OMA`).

This module is deliberately independent of the SymbolicUtils pipeline: it
loads rules, exposes their OpenMath symbols, domains, provenance and Lean
verification metadata, and applies them with a plain syntactic matcher.

A rule's Lean certificate covers the *mathematical* statement only.  The
matcher, the substitution and the rewrite strategy implemented here are not
verified; their behaviour is tested separately.
"""
module OSRv1

using JSON

export OMS, OMV, OMI, OMA, OMExpr, parse_omjson, to_omjson
export RuleSet, Rule, Verification, load_ruleset, verification
export match_pattern, substitute, rewrite, RewriteStep, RewriteResult

abstract type OMExpr end

"""OpenMath symbol `cd#name` (CD base `http://www.openmath.org/cd`)."""
struct OMS <: OMExpr
    cd::String
    name::String
end

"""OpenMath variable."""
struct OMV <: OMExpr
    name::String
end

"""OpenMath integer."""
struct OMI <: OMExpr
    value::BigInt
end
OMI(x::Integer) = OMI(BigInt(x))

# `BigInt` is a mutable type, so the default structural `==` of `OMI` would
# compare object identity.  Integers are compared by value.
Base.:(==)(a::OMI, b::OMI) = a.value == b.value
Base.hash(a::OMI, h::UInt) = hash(a.value, hash(:OMI, h))

"""OpenMath application of a symbol to arguments."""
struct OMA <: OMExpr
    head::OMS
    args::Vector{OMExpr}
end

Base.:(==)(a::OMA, b::OMA) = a.head == b.head && a.args == b.args
Base.hash(a::OMA, h::UInt) = hash(a.args, hash(a.head, hash(:OMA, h)))

const _SUPPORTED_SETS = Dict(:real => OMS("setname1", "R"), :complex => OMS("setname1", "C"),
    :boolean => OMS("setname2", "Boolean"))

"""
    parse_omjson(json)

Parse an OpenMath JSON object of the OSR fragment.  Anything else (floats,
strings, binders, attributions, non-symbol applicants) is rejected.
"""
function parse_omjson(j)
    j isa AbstractDict || throw(ArgumentError("OpenMath JSON object expected, got $(typeof(j))"))
    kind = get(j, "kind", nothing)
    if kind == "OMS"
        return OMS(String(j["cd"]), String(j["name"]))
    elseif kind == "OMV"
        return OMV(String(j["name"]))
    elseif kind == "OMI"
        haskey(j, "integer") || throw(ArgumentError("only JSON-integer OMI is supported"))
        return OMI(j["integer"])
    elseif kind == "OMA"
        head = parse_omjson(j["applicant"])
        head isa OMS || throw(ArgumentError("OMA applicant must be an OMS in the OSR fragment"))
        args = OMExpr[parse_omjson(a) for a in j["arguments"]]
        isempty(args) && throw(ArgumentError("OMA without arguments"))
        return OMA(head, args)
    end
    throw(ArgumentError("unsupported OpenMath JSON kind: $(repr(kind))"))
end

"""
    to_omjson(expr)

Encode an expression in the OpenMath 2.0 JSON encoding.
"""
to_omjson(e::OMS) = Dict("kind" => "OMS", "cd" => e.cd, "name" => e.name)
to_omjson(e::OMV) = Dict("kind" => "OMV", "name" => e.name)
to_omjson(e::OMI) = Dict("kind" => "OMI", "integer" => e.value)
to_omjson(e::OMA) = Dict("kind" => "OMA", "applicant" => to_omjson(e.head),
    "arguments" => [to_omjson(a) for a in e.args])

"""Lean verification record of a rule in one domain."""
struct Verification
    domain::Symbol
    status::String
    certified::Bool
    mapping_assurance::String
    theorem::Union{Nothing,String}
    statement::Union{Nothing,String}
    axioms::Vector{String}
    lean_toolchain::String
    mathlib_revision::String
    source_digest::String
    module_name::String
end

"""An oriented rewrite rule."""
struct Rule
    id::String
    legacy_id::Union{Nothing,String}
    description::String
    variables::Vector{String}
    pattern::OMExpr
    replacement::OMExpr
    conditions::Vector{OMExpr}
    profiles::Vector{String}
    priority::Int
    symbols::Vector{OMS}
    provenance::Dict{String,Any}
    verification::Vector{Verification}
    findings::Vector{String}
end

"""A loaded rule set."""
struct RuleSet
    name::String
    format::String
    build::Dict{String,Any}
    symbols::Vector{Dict{String,Any}}
    profiles::Dict{String,Vector{String}}
    rules::Dict{String,Rule}
end

function _symbol_from_uri(uri::AbstractString)
    m = match(r"^http://www\.openmath\.org/cd/([A-Za-z0-9_]+)#([A-Za-z0-9_]+)$", uri)
    m === nothing && throw(ArgumentError("not an OpenMath symbol URI: $(uri)"))
    return OMS(m.captures[1], m.captures[2])
end

function _verification(j)
    dom = Symbol(j["domain"])
    haskey(_SUPPORTED_SETS, dom) || throw(ArgumentError("unknown domain $(dom)"))
    parse_omjson(j["carrier"]) == _SUPPORTED_SETS[dom] ||
        throw(ArgumentError("carrier does not match domain $(dom)"))
    Verification(dom, j["status"], j["certified"], j["mapping_assurance"],
        get(j, "theorem", nothing), get(j, "statement", nothing),
        String.(j["axioms"]), j["lean_toolchain"], j["mathlib_revision"],
        j["source_digest"], j["module"])
end

_omsyms(e::OMS) = [e]
_omsyms(::OMV) = OMS[]
_omsyms(::OMI) = OMS[]
_omsyms(e::OMA) = vcat([e.head], (_omsyms(a) for a in e.args)...)

_vars(::OMS) = String[]
_vars(e::OMV) = [e.name]
_vars(::OMI) = String[]
_vars(e::OMA) = vcat(String[], (_vars(a) for a in e.args)...)

function _rule(j)
    vars = String[v["name"] for v in j["variables"]]
    pattern = parse_omjson(j["pattern"])
    replacement = parse_omjson(j["replacement"])
    conditions = OMExpr[parse_omjson(c) for c in j["conditions"]]
    j["orientation"] == "forward" || throw(ArgumentError("unsupported orientation $(j["orientation"])"))
    j["applicability"] == "defined_pattern" ||
        throw(ArgumentError("unsupported applicability $(j["applicability"])"))
    issubset(_vars(replacement), _vars(pattern)) ||
        throw(ArgumentError("rule $(j["id"]): replacement uses unbound variables"))
    issubset(_vars(pattern), vars) || throw(ArgumentError("rule $(j["id"]): undeclared variables"))
    symbols = OMS[_symbol_from_uri(s) for s in j["symbols"]]
    used = Set(vcat(_omsyms(pattern), _omsyms(replacement), (_omsyms(c) for c in conditions)...))
    used == Set(symbols) || throw(ArgumentError("rule $(j["id"]): declared symbols differ from used symbols"))
    Rule(j["id"], get(j, "legacy_id", nothing), j["description"], vars, pattern, replacement,
        conditions, String.(j["profiles"]), j["priority"], symbols, j["provenance"],
        Verification[_verification(v) for v in j["verification"]], String.(j["findings"]))
end

"""
    load_ruleset(path)

Load an OSR v1 rule set.  Every symbol used by a rule must be declared in the
rule set's symbol table, and profiles may only reference existing rules.
"""
function load_ruleset(path::AbstractString)
    j = JSON.parsefile(path; dicttype=Dict{String,Any})
    fmt = j["osr_format"]
    startswith(fmt, "1.") || throw(ArgumentError("unsupported OSR format $(fmt)"))
    rules = Dict{String,Rule}()
    for rj in j["rules"]
        r = _rule(rj)
        haskey(rules, r.id) && throw(ArgumentError("duplicate rule id $(r.id)"))
        rules[r.id] = r
    end
    declared = Set(OMS(s["cd"], s["name"]) for s in j["symbols"])
    for r in values(rules), s in r.symbols
        s in declared || throw(ArgumentError("rule $(r.id) uses undeclared symbol $(s.cd)#$(s.name)"))
    end
    profiles = Dict{String,Vector{String}}()
    for (name, p) in j["profiles"]
        ids = String.(p["rules"])
        for id in ids
            haskey(rules, id) || throw(ArgumentError("profile $(name) references unknown rule $(id)"))
        end
        profiles[name] = ids
    end
    RuleSet(j["ruleset"], fmt, j["build"], j["symbols"], profiles, rules)
end

"""
    verification(rule, domain)

The verification record of `rule` for `domain` (`:real`, `:complex` or `:boolean`).
"""
function verification(r::Rule, domain::Symbol)
    i = findfirst(v -> v.domain == domain, r.verification)
    i === nothing && throw(ArgumentError("rule $(r.id) has no record for domain $(domain)"))
    return r.verification[i]
end

"""
    match_pattern(pattern, expr, variables) -> Union{Nothing,Dict{String,OMExpr}}

Syntactic first-order matching.  An `OMV` whose name is in `variables` is a
pattern variable; repeated occurrences must match equal subterms.  No
associativity or commutativity is assumed.
"""
function match_pattern(pattern::OMExpr, expr::OMExpr, variables)
    b = Dict{String,OMExpr}()
    return _match!(b, pattern, expr, variables) ? b : nothing
end

function _match!(b, p::OMV, e, variables)
    p.name in variables || return e == p
    if haskey(b, p.name)
        return b[p.name] == e
    end
    b[p.name] = e
    return true
end
_match!(b, p::OMS, e, variables) = e == p
_match!(b, p::OMI, e, variables) = e == p
function _match!(b, p::OMA, e, variables)
    e isa OMA && e.head == p.head && length(e.args) == length(p.args) || return false
    all(_match!(b, pa, ea, variables) for (pa, ea) in zip(p.args, e.args))
end

"""
    substitute(expr, bindings)

Replace every variable bound in `bindings`.  Rule replacements contain no
binders, so substitution cannot capture variables.
"""
substitute(e::OMV, b) = get(b, e.name, e)
substitute(e::OMS, b) = e
substitute(e::OMI, b) = e
substitute(e::OMA, b) = OMA(e.head, OMExpr[substitute(a, b) for a in e.args])

"""One applied rule."""
struct RewriteStep
    rule::String
    theorem::Union{Nothing,String}
    certified::Bool
    before::OMExpr
    after::OMExpr
end

"""Result of `rewrite`."""
struct RewriteResult
    expr::OMExpr
    steps::Vector{RewriteStep}
    exhausted::Bool
end

function _eligible(rs::RuleSet, profile, domain, certified_only)
    haskey(rs.profiles, profile) || throw(ArgumentError("unknown profile $(profile)"))
    haskey(_SUPPORTED_SETS, domain) || throw(ArgumentError("unknown domain $(domain)"))
    out = Rule[]
    for id in rs.profiles[profile]
        r = rs.rules[id]
        v = verification(r, domain)
        certified_only && !v.certified && continue
        # Conditions need a decision procedure; this engine applies only
        # unconditional rules rather than guessing.
        isempty(r.conditions) || continue
        push!(out, r)
    end
    return out
end

function _step(e::OMExpr, rules, domain)
    for r in rules
        b = match_pattern(r.pattern, e, Set(r.variables))
        if b !== nothing
            after = substitute(r.replacement, b)
            v = verification(r, domain)
            return after, RewriteStep(r.id, v.theorem, v.certified, e, after)
        end
    end
    if e isa OMA
        for (i, a) in enumerate(e.args)
            res = _step(a, rules, domain)
            if res !== nothing
                args = copy(e.args)
                args[i] = res[1]
                return OMA(e.head, args), res[2]
            end
        end
    end
    return nothing
end

"""
    rewrite(expr, ruleset; profile, domain, certified_only=true, max_steps=100)

Rewrite `expr` with the rules of `profile`, valid in `domain`.  The strategy is
outermost-first, leftmost, trying rules in profile order, repeated until no
rule applies or `max_steps` is reached.  `exhausted` is `true` when the budget
is spent and a rule still applies.  This is the strategy of the Lean reference
rewriter `OSR.normalize`; the Conformance cases check the two agree.

Each rule is sound where its pattern is defined (`applicability =
defined_pattern`): the result agrees with the input wherever the input is
defined, and may be defined at more points.  With `certified_only`, only rules
certified in `domain` are used.
"""
function rewrite(expr::OMExpr, rs::RuleSet; profile::AbstractString, domain::Symbol,
        certified_only::Bool=true, max_steps::Integer=100)
    rules = _eligible(rs, profile, domain, certified_only)
    steps = RewriteStep[]
    e = expr
    while length(steps) < max_steps
        res = _step(e, rules, domain)
        res === nothing && return RewriteResult(e, steps, false)
        e = res[1]
        push!(steps, res[2])
    end
    # The budget is exhausted only if another rule would still apply.
    return RewriteResult(e, steps, _step(e, rules, domain) !== nothing)
end

end # module OSRv1
