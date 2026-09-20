module OpenSymbolicRules

using JSON
import CommonSolve
import CommonSolve: solve, init, solve!
using PrecompileTools: @setup_workload, @compile_workload
using SymbolicUtils
using SymbolicUtils: @rule, Sym, Term
using SymbolicUtils: iscall, arguments

include("predicates.jl")
include("constraints.jl")
include("binders.jl")
include("simplify.jl")
include("dispatch.jl")
include("groebner.jl")
include("operations.jl")
include("polynomial_operations.jl")
include("sat.jl")
include("equality_theory.jl")
include("linear_theory.jl")
include("equations.jl")
include("equation_operations.jl")
include("prove.jl")
include("piecewise.jl")
include("domains.jl")
include("context.jl")
include("bridge.jl")
include("manifests.jl")
include("heads.jl")
include("exact_radicals.jl")

export @load_osr, @load_osr_profile, rule_paths, load_inference_profile, OSRInference, OSRRule
export FreeQ, is_integer, is_numeric, NotEqual
export build_simplifier

"""
    from_openmath(object)

Convert a typed OpenMath object into an OSR/SymbolicUtils expression.  This
function is available when the optional `OpenMath.jl` extension is loaded.
"""
function from_openmath end
"""
    to_openmath(expression)

Convert an OSR/SymbolicUtils expression into a typed OpenMath object.  This
function is available when the optional `OpenMath.jl` extension is loaded.
"""
function to_openmath end
export from_openmath, to_openmath

"""
    _DEFAULT_SEMANTICS

OpenMath Content Dictionary symbol of every canonical OSR head.  A rule file
declares its own `semantics` block, and that declaration always wins; this map
only resolves heads used outside a rule file, for example when `osr_to_expr` is
called directly.
"""
const _DEFAULT_SEMANTICS = Dict(
    "Add" => "openmath:arith1#plus",
    "Multiply" => "openmath:arith1#times",
    "And" => "openmath:logic1#and",
    "Or" => "openmath:logic1#or",
    "List" => "openmath:list1#list",
    "Piecewise" => "openmath:piece1#piecewise",
    "Piece" => "openmath:piece1#piece",
    "Otherwise" => "openmath:piece1#otherwise",
)

"""
    _ASSOCIATIVE_SYMBOLS

OpenMath symbols denoting associative operations.  An n-ary OSR expression with
such a head is normalized to left-associated binary `SymbolicUtils` terms.
"""
const _ASSOCIATIVE_SYMBOLS = Set([
    "openmath:arith1#plus",
    "openmath:arith1#times",
    "openmath:logic1#and",
    "openmath:logic1#or",
    "openmath:logic1#xor",
])

"""
    _COMMUTATIVE_SYMBOLS

OpenMath symbols denoting operations whose operands may be reordered.  Patterns
headed by one of these compile to a `SymbolicUtils.ACRule`, so a single rule
matches every operand order instead of requiring a mirrored copy per order.

`openmath:arith1#times` is deliberately absent.  An OSR expression carries no
shape information, so a `times` operand may be a matrix or a tensor and
reordering it would be unsound.  The same applies to tensor products,
contractions, and axis permutations, which must use dedicated heads.
"""
const _COMMUTATIVE_SYMBOLS = Set([
    "openmath:arith1#plus",
    "openmath:logic1#and",
    "openmath:logic1#or",
    "openmath:logic1#xor",
    "openmath:logic1#xnor",
    "openmath:logic1#nand",
    "openmath:logic1#nor",
    "openmath:logic1#equivalent",
])

"""
    _openmath_symbol(head, semantics)

Return the OpenMath symbol bound to `head`, or `nothing` when the head has no
declared and no canonical binding.
"""
function _openmath_symbol(head::AbstractString, semantics)
    symbol = get(semantics, head, nothing)
    symbol isa AbstractString && return String(symbol)
    return get(_DEFAULT_SEMANTICS, head, nothing)
end

_is_associative(head, semantics) = _openmath_symbol(head, semantics) in _ASSOCIATIVE_SYMBOLS
_is_commutative(head, semantics) = _openmath_symbol(head, semantics) in _COMMUTATIVE_SYMBOLS

"""
    _nonempty_match(matched)

Return whether a sequence wildcard bound at least one expression.  OSR's `__`
spelling requires a non-empty match, whereas `___` accepts an empty one.
"""
_nonempty_match(matched) = !isempty(matched)

"""
    _WILDCARD_DOMAINS

Predicate guarding a typed blank such as `m_integer`.
"""
const _WILDCARD_DOMAINS = Dict{String,Symbol}(
    "integer" => :IntegerQ,
    "rational" => :RationalQ,
    "real" => :is_real,
    "complex" => :is_complex,
    "number" => :is_numeric,
    "numeric" => :is_numeric,
    "symbol" => :is_symbol,
)

"""
    _OPTIONAL_WILDCARD

Spelling of an OSR optional operand: a name, a dot, and an optional explicit
default such as `m.3` or `n.-1`.  Per OSR-W-002 and OSR-W-002a.
"""
const _OPTIONAL_WILDCARD = r"^([a-zA-Z][a-zA-Z0-9]*)\.(-?[0-9]+)?$"

"""
    _optional_default(symbol, index)

Return the value an absent operand takes at argument position `index` of the
operation denoted by the OpenMath `symbol`, or `nothing` when the operation
supplies no such value.

An optional operand only means something where the operation has an identity
element to fall back on: `plus` contributes zero and `times` contributes one.
`power` is deliberately asymmetric — an absent exponent is one, whereas an
absent base has no meaning, so only its second argument defaults.
"""
function _optional_default(symbol, index::Integer)
    symbol === nothing && return nothing
    symbol == "openmath:arith1#plus" && return 0
    symbol == "openmath:arith1#times" && return 1
    symbol == "openmath:arith1#power" && return index == 2 ? 1 : nothing
    return nothing
end

"""
    _wildcard_to_expr(node; reference=false, optional_default=nothing)

Compile an OSR v0.1 wildcard spelling into a `SymbolicUtils` matcher pattern, or
return `nothing` when `node` names an ordinary symbol.  A `reference` wildcard
stands for a binding the pattern already made — as in a rule's result or in a
constraint argument — so it carries no predicate of its own.

| spelling | meaning | pattern |
| --- | --- | --- |
| `~x` | slot | `~x` |
| `x_` | blank | `~x` |
| `x_<domain>` | typed blank | `~x::<predicate>` |
| `xs__` | sequence, at least one | `~~xs::_nonempty_match` |
| `xs___` | sequence, possibly empty | `~~xs` |
| `a.` | optional operand | `~!a` |
| `m.3` | optional operand, explicit default | `~!m` |

Matching an optional operand needs the identity element of the enclosing
operation, which `osr_to_expr` supplies as `optional_default`; an explicit
default in the spelling itself wins over it.  With neither there is nothing for
an absent operand to bind, so the wildcard is rejected rather than compiled into
a rule that could never fire.

The default-valued slot is emitted as an interpolation, which `SymbolicUtils`
splices into the pattern verbatim.  The `~!a` spelling of `@rule` cannot be used
instead: it resolves the default from the Julia operator it sits under, and OSR
heads are uninterpreted symbols rather than `+`, `*`, and `^`.
"""
function _wildcard_to_expr(node::AbstractString; reference::Bool=false,
                           optional_default=nothing)
    if startswith(node, "~")
        name = node[2:end]
        isempty(name) && throw(ArgumentError("OSR wildcard `$(node)` has no name"))
        return Expr(:call, :~, Symbol(name))
    end

    optional = match(_OPTIONAL_WILDCARD, node)
    if optional === nothing && occursin('.', node)
        throw(ArgumentError("OSR optional wildcard `$(node)` is malformed"))
    end
    if optional !== nothing
        name = Symbol(optional.captures[1])
        # In a result or a constraint the wildcard refers to the binding the
        # pattern already made, whether that binding came from a matched
        # operand or from the default.
        reference && return Expr(:call, :~, name)

        declared = optional.captures[2]
        default = declared === nothing ? optional_default : parse(Int, declared)
        default === nothing && throw(ArgumentError(
            "OSR optional wildcard `$(node)` is not supported here: matching an " *
            "optional operand requires an identity element, which neither the " *
            "wildcard nor the enclosing operation supplies"))

        return Expr(:$, Expr(:call, GlobalRef(SymbolicUtils, :DefSlot),
                             QuoteNode(name), GlobalRef(SymbolicUtils, :alwaystrue),
                             nothing, default))
    end

    if endswith(node, "___")
        name = node[1:end-3]
        isempty(name) && throw(ArgumentError("OSR wildcard `$(node)` has no name"))
        return Expr(:call, :~, Expr(:call, :~, Symbol(name)))
    end

    if endswith(node, "__")
        name = node[1:end-2]
        isempty(name) && throw(ArgumentError("OSR wildcard `$(node)` has no name"))
        reference && return Expr(:call, :~, Expr(:call, :~, Symbol(name)))
        guard = Expr(:(::), Symbol(name), GlobalRef(@__MODULE__, :_nonempty_match))
        return Expr(:call, :~, Expr(:call, :~, guard))
    end

    if endswith(node, "_")
        name = node[1:end-1]
        isempty(name) && throw(ArgumentError("OSR wildcard `$(node)` has no name"))
        return Expr(:call, :~, Symbol(name))
    end

    separator = findlast('_', node)
    separator === nothing && return nothing
    name = node[1:separator-1]
    domain = node[separator+1:end]
    isempty(name) && throw(ArgumentError("OSR wildcard `$(node)` has no name"))
    all(islowercase, domain) || return nothing

    predicate = get(_WILDCARD_DOMAINS, domain, nothing)
    predicate === nothing && throw(ArgumentError(
        "OSR typed wildcard `$(node)` declares the unknown domain `$(domain)`"))
    reference && return Expr(:call, :~, Symbol(name))
    return Expr(:call, :~, Expr(:(::), Symbol(name), GlobalRef(@__MODULE__, predicate)))
end

"""
    _pattern_bindings(pattern)

Return the names a pattern binds, whatever spelling each wildcard uses.

A rule's pattern declares its wildcards; its result and its constraints refer to
the bindings it made. RUBI spells the declaration `m_` and the reference `m`,
so resolving a reference needs the set of names the pattern established.
"""
function _pattern_bindings(pattern)
    names = Set{Symbol}()
    _pattern_bindings!(names, pattern)
    return names
end

function _pattern_bindings!(names::Set{Symbol}, node)
    if node isa AbstractString
        compiled = _wildcard_to_expr(node; reference=true)
        compiled === nothing && return names
        # Every wildcard spelling compiles to `~name` under `reference`, and a
        # segment to `~~name`; the name is the innermost symbol either way.
        while compiled isa Expr && compiled.head === :call && compiled.args[1] === :~
            compiled = compiled.args[2]
        end
        compiled isa Symbol && push!(names, compiled)
    elseif node isa AbstractArray
        for element in node
            _pattern_bindings!(names, element)
        end
    end
    return names
end

"""
    osr_to_expr(node, semantics=_DEFAULT_SEMANTICS; reference=false, optional_default=nothing, bindings=nothing, heads=nothing)

Recursively parse an OSR JSON node into a Julia expression for SymbolicUtils.
`semantics` is the rule file's head-to-OpenMath-symbol map; it decides which
n-ary expressions are normalized to left-associated binary terms.  Set
`reference` when compiling a rule's result or a constraint argument, where a
wildcard refers to a binding the pattern already made.

`optional_default` is the value an absent operand takes at this position, which
the enclosing operation supplies as the recursion descends.  A top-level node
has no enclosing operation and therefore no default.

`bindings` names what the rule's pattern bound.  Under `reference`, a bare name
in that set is a reference to its binding rather than a free symbol, which is
how RUBI spells a wildcard `m_` in a pattern and `m` in the result.

`heads` says what each operator resolves to, as [`_resolve_heads`](@ref)
determined.  Without it a head resolves to a bare symbol of its own name, which
is what direct callers of this function expect.
"""
function osr_to_expr(node, semantics=_DEFAULT_SEMANTICS; reference::Bool=false,
                     optional_default=nothing, bindings=nothing, heads=nothing)
    if node isa String
        node == "True" && return true
        node == "False" && return false
        wildcard = _wildcard_to_expr(node; reference, optional_default)
        wildcard === nothing || return wildcard
        symbol = Symbol(node)
        reference && bindings !== nothing && symbol in bindings &&
            return Expr(:call, :~, symbol)
        # Normal symbol/function
        return symbol
    elseif node isa AbstractArray
        if length(node) == 3 && node[1] isa String && node[1] in ("Forall", "Exists")
            variables = node[2]
            variables isa AbstractArray || throw(ArgumentError("Quantifier variables must be an array"))
            all(variable -> variable isa String, variables) || throw(ArgumentError("Quantifier variables must be strings"))
            if length(variables) == 1 && endswith(only(variables), "__")
                sequence_name = only(variables)
                isempty(sequence_name[1:end-2]) && throw(ArgumentError("Quantifier sequence variables must have a name"))
                bound_variables = Expr(:call, :~, Symbol(sequence_name[1:end-2]))
                return Expr(:call, Symbol(node[1]), bound_variables, osr_to_expr(node[3], semantics; reference, bindings, heads))
            end
            bound_variables = Expr(:vect, [QuoteNode(Symbol(variable)) for variable in variables]...)
            return Expr(:call, Symbol(node[1]), bound_variables, osr_to_expr(node[3], semantics; reference, bindings, heads))
        end
        if node[1] == "List"
            # A list is a collection of expressions, not a mathematical
            # operation, so it compiles to a Julia vector.
            return Expr(:vect, map(element -> osr_to_expr(element, semantics; reference, bindings, heads), node[2:end])...)
        end
        # Function call, e.g. ["Multiply", "x", "y"] -> Multiply(x, y).  The
        # head may itself be a wildcard, as in the RUBI rules that match any of
        # the six trigonometric heads at once (OSR-X-004).
        head_wildcard = node[1] isa String ? _wildcard_to_expr(node[1]; reference) : nothing
        if head_wildcard === nothing && reference && bindings !== nothing &&
           node[1] isa String && Symbol(node[1]) in bindings
            head_wildcard = Expr(:call, :~, Symbol(node[1]))
        end
        op = if head_wildcard !== nothing
            head_wildcard
        elseif heads !== nothing && haskey(heads, node[1])
            heads[node[1]]
        else
            Symbol(node[1])
        end
        # The head decides what an absent operand binds to, so it is resolved
        # once here and handed to each argument with its own position.  A
        # wildcard head denotes no particular operation and so supplies none.
        symbol = head_wildcard === nothing ? _openmath_symbol(node[1], semantics) : nothing
        args = [osr_to_expr(argument, semantics; reference, bindings, heads,
                            optional_default=_optional_default(symbol, index))
                for (index, argument) in enumerate(node[2:end])]
        if length(args) > 2 && symbol in _ASSOCIATIVE_SYMBOLS
            return reduce((left, right) -> Expr(:call, op, left, right), args)
        end
        return Expr(:call, op, args...)
    else
        # Literals like numbers
        return node
    end
end

"""
    _OSR_PREDICATES

Julia function implementing each OSR constraint predicate.  A predicate that is
not listed here is resolved in the module that loads the rule file, so a host
can supply its own without changing this library.
"""
const _OSR_PREDICATES = Dict{String,Symbol}(
    # Spellings inherited from the OSR fixtures.
    "PositiveQ" => :is_positive,
    "NegativeQ" => :is_negative,
    "NonzeroQ" => :is_nonzero,
    "RealQ" => :is_real,
    "ComplexQ" => :is_complex,
    "NumericQ" => :is_numeric,
    "NotEqual" => :NeQ,
    # Mathematica spellings used by the RUBI dataset.
    "Equal" => :EqQ,
    "Unequal" => :NeQ,
    "Greater" => :GtQ,
    "Less" => :LtQ,
    "GreaterEqual" => :GeQ,
    "LessEqual" => :LeQ,
    # RUBI spellings, each implemented under its own name.
    (name => Symbol(name) for name in (
        "FreeQ",
        "EqQ", "NeQ", "GtQ", "LtQ", "GeQ", "LeQ",
        "IntegerQ", "IntegersQ", "IGtQ", "ILtQ", "IGeQ", "ILeQ",
        "RationalQ", "FractionQ", "HalfIntegerQ", "PosQ", "NegQ", "FalseQ",
        "AtomQ", "SumQ", "ProductQ", "PowerQ", "MemberQ",
        "PolynomialQ", "PolyQ", "LinearQ", "QuadraticQ",
    ))...,
)

_conjoin(conditions) = foldr((left, right) -> Expr(:&&, left, right), conditions)

"""
    UnprovedConstraint(predicate)

Raised while evaluating a guard that names a predicate no implementation can be
found for, in this package or in the module that loaded the rule file.

A predicate answers `true` only when the property is established, so one that
cannot be evaluated establishes nothing. Raising rather than answering `false`
is what keeps `Not` honest: answering `false` would make `Not` answer `true` and
license a rewrite on a property nobody decided.
"""
struct UnprovedConstraint <: Exception
    predicate::String
end

Base.showerror(io::IO, error::UnprovedConstraint) =
    print(io, "OSR constraint predicate `", error.predicate,
          "` has no implementation, so its guard is unproved")

"""
    _unproved(predicate)

Abandon the guard being evaluated because `predicate` cannot be decided.
"""
_unproved(predicate::String) = throw(UnprovedConstraint(predicate))

"""
    _guard_or_unproved(condition)

Wrap a compiled guard so that an undecidable predicate leaves it unestablished
instead of propagating.

`&&` and `||` short-circuit, which gives the guard exactly the three-valued
reading it needs at no cost: `Or(p, undecidable)` still holds when `p` does,
because the undecidable branch is never reached, while `Not(undecidable)` and
`And(p, undecidable)` reach it and establish nothing.
"""
function _guard_or_unproved(condition)
    return Expr(:block, Expr(:try, Expr(:block, condition), :exception,
        Expr(:block,
             Expr(:||, Expr(:call, :isa, :exception,
                            GlobalRef(@__MODULE__, :UnprovedConstraint)),
                  Expr(:call, GlobalRef(Base, :rethrow))),
             false)))
end

"""
    _predicate_callee(name, caller)

Return what a constraint predicate named `name` compiles to: this package's
implementation, one the `caller` supplies, or a call that abandons the guard.
"""
function _predicate_callee(name::AbstractString, caller::Union{Nothing,Module})
    predicate = get(_OSR_PREDICATES, name, nothing)
    predicate === nothing || return GlobalRef(@__MODULE__, predicate)
    symbol = Symbol(name)
    caller === nothing && return symbol
    isdefined(caller, symbol) && return symbol
    return nothing
end

"""
    _CONSTRAINT_COMBINATORS

Constraint heads whose operands are themselves constraints.  They are rule
language rather than domain vocabulary: each compiles to Julia control flow over
booleans, never to a symbolic term, and none needs an OpenMath binding.
"""
const _CONSTRAINT_COMBINATORS = Set(["Not", "And", "Or", "If"])

"""
    _compile_constraint(constraint, semantics)

Compile one OSR constraint into a Julia expression that evaluates to a `Bool`.
`Not`, `And`, and `Or` are constraint combinators: they nest constraints and
compile to Julia control flow, never to a symbolic logic term.
"""
function _compile_constraint(constraint, semantics; bindings=nothing, heads=nothing, caller=nothing)
    constraint isa AbstractArray && !isempty(constraint) ||
        throw(ArgumentError("OSR constraints must be non-empty arrays"))
    name = first(constraint)
    name isa String || throw(ArgumentError("OSR constraint predicates must be named by a string"))
    operands = constraint[2:end]

    if name == "Not"
        length(operands) == 1 || throw(ArgumentError("The `Not` constraint takes exactly one constraint"))
        return Expr(:call, :!, _compile_constraint(only(operands), semantics; bindings, heads, caller))
    elseif name == "If"
        length(operands) == 3 ||
            throw(ArgumentError("The `If` constraint takes a test and two branches"))
        return Expr(:if, [_compile_constraint(operand, semantics; bindings, heads, caller) for operand in operands]...)
    elseif name == "And" || name == "Or"
        isempty(operands) && throw(ArgumentError("The `$(name)` constraint takes at least one constraint"))
        compiled = [_compile_constraint(operand, semantics; bindings, heads, caller) for operand in operands]
        head = name == "And" ? :&& : :||
        return foldr((left, right) -> Expr(head, left, right), compiled)
    end

    callee = _predicate_callee(name, caller)
    # Nothing can decide this predicate, so the guard is abandoned rather than
    # answered.  Its operands are not built either: they would be discarded.
    callee === nothing &&
        return Expr(:call, GlobalRef(@__MODULE__, :_unproved), String(name))
    return Expr(:call, callee,
                map(operand -> osr_to_expr(operand, semantics; reference=true, bindings, heads), operands)...)
end

"""
    _rule_macro(pattern, semantics)

Return the `SymbolicUtils` rule macro a pattern must be compiled with.  A
pattern headed by a commutative operation becomes an `@acrule`, which matches
every operand order with a single rule instead of one rule per order.
"""
function _rule_macro(pattern, semantics)
    pattern isa Expr || return Symbol("@rule")
    pattern.head === :call || return Symbol("@rule")
    length(pattern.args) >= 3 || return Symbol("@rule")
    head = pattern.args[1]
    head isa Symbol || return Symbol("@rule")
    return _is_commutative(String(head), semantics) ? Symbol("@acrule") : Symbol("@rule")
end

function _compile_rule_exprs(rules_json; identity::AbstractString="unknown",
                             semantics=_DEFAULT_SEMANTICS, heads=nothing, caller=nothing)
    rule_exprs = Expr[]
    seen_ids = Set{Int}()
    for rule in rules_json
        id = get(rule, "id", nothing)
        id isa Integer || throw(ArgumentError("Every OSR rule must have an integer id"))
        id in seen_ids && throw(ArgumentError("Duplicate OSR rule id $(id) in rule file $(identity)"))
        push!(seen_ids, id)

        pattern = osr_to_expr(rule["pattern"], semantics; heads)
        # A result and a constraint refer to the bindings the pattern made,
        # which RUBI spells by bare name: `m_` declares and `m` refers.
        bindings = _pattern_bindings(rule["pattern"])
        result = osr_to_expr(rule["result"], semantics; reference=true, bindings, heads)
        constraints_json = get(rule, "constraints", [])
        rule_macro = _rule_macro(pattern, semantics)

        rewrite = if isempty(constraints_json)
            Expr(:macrocall, GlobalRef(SymbolicUtils, rule_macro), LineNumberNode(0), :($pattern => $result))
        else
            condition = _guard_or_unproved(
                _conjoin([_compile_constraint(constraint, semantics; bindings, heads, caller)
                          for constraint in constraints_json]))
            Expr(:macrocall, GlobalRef(SymbolicUtils, rule_macro), LineNumberNode(0), :($pattern => $result where $condition))
        end
        name = "$(identity):$(id)"
        description = get(rule, "description", nothing)
        provenance = get(rule, "provenance", nothing)
        provenance === nothing || provenance isa AbstractDict || throw(ArgumentError("Rule $(name) has invalid provenance"))
        push!(rule_exprs, :(OSRRule($name, $description, $(QuoteNode(provenance)), $rewrite)))
    end
    return rule_exprs
end

function _validate_rule_identities(documents)
    identities = Set{String}()
    for document in documents
        file_identity = get(document, "identity", get(document, "section", nothing))
        file_identity isa String || throw(ArgumentError("Every OSR rule file must have a string identity"))
        for rule in get(document, "rules", Any[])
            id = get(rule, "id", nothing)
            id isa Integer || throw(ArgumentError("Every OSR rule must have an integer id"))
            rule_identity = "$(file_identity):$(id)"
            rule_identity in identities && throw(ArgumentError("Duplicate OSR rule identity $(rule_identity)"))
            push!(identities, rule_identity)
        end
    end
    return nothing
end

const _OPENMATH_SYMBOL = r"^openmath:[A-Za-z][A-Za-z0-9_]*#[A-Za-z][A-Za-z0-9_]*$"

"""
    _STRUCTURAL_HEADS

Heads the OSR expression language defines for itself rather than borrowing from
a mathematical domain.  They compile to a host collection instead of a term, so
a rule file binds no domain meaning by redeclaring one and is not required to.
"""
const _STRUCTURAL_HEADS = Set(["List", "Condition"])

function _collect_operators!(operators::Set{String}, expression; bindings=nothing)
    expression isa AbstractArray || return nothing
    isempty(expression) && throw(ArgumentError("OSR expressions cannot be empty arrays"))
    operator = first(expression)
    operator isa String || throw(ArgumentError("OSR expression operators must be strings"))
    # A structural head carries no domain meaning, and a wildcard in operator
    # position names a binding rather than an operation — whether it is spelled
    # as one or referred to by the bare name the pattern bound.  None of them
    # needs an OpenMath symbol.
    bound = bindings !== nothing && Symbol(operator) in bindings
    if !(operator in _STRUCTURAL_HEADS) && !bound && _wildcard_to_expr(operator) === nothing
        push!(operators, operator)
    end

    if operator == "Condition"
        # A guarded pattern: an expression and the test that admits it.  Only
        # the expression carries domain vocabulary.
        length(expression) == 3 ||
            throw(ArgumentError("An OSR `Condition` requires a pattern and a test"))
        _collect_operators!(operators, expression[2]; bindings)
        _collect_constraint_operators!(operators, expression[3]; bindings)
    elseif operator in ("Forall", "Exists")
        length(expression) == 3 || throw(ArgumentError("OSR quantifiers require variables and a body"))
        _collect_operators!(operators, expression[3]; bindings)
    else
        for argument in expression[2:end]
            _collect_operators!(operators, argument; bindings)
        end
    end
    return nothing
end

"""
    _collect_constraint_operators!(operators, constraint)

Collect the mathematical operators a constraint applies its predicates to.  A
predicate name is not a mathematical operator and needs no OpenMath binding,
and a combinator nests constraints rather than expressions.
"""
function _collect_constraint_operators!(operators::Set{String}, constraint; bindings=nothing)
    constraint isa AbstractArray && !isempty(constraint) ||
        throw(ArgumentError("OSR constraints must be non-empty arrays"))
    name = first(constraint)
    name isa String || throw(ArgumentError("OSR constraint predicates must be named by a string"))

    if name in _CONSTRAINT_COMBINATORS
        for operand in constraint[2:end]
            _collect_constraint_operators!(operators, operand; bindings)
        end
        return nothing
    end

    for argument in constraint[2:end]
        _collect_operators!(operators, argument; bindings)
    end
    return nothing
end

function _validate_openmath_semantics(documents)
    for document in documents
        semantics = get(document, "semantics", nothing)
        semantics isa AbstractDict || throw(ArgumentError("Every OSR rule file must declare semantics"))
        for (operator, symbol) in semantics
            operator isa String || throw(ArgumentError("OSR semantics keys must be strings"))
            symbol isa String && occursin(_OPENMATH_SYMBOL, symbol) || throw(ArgumentError("Invalid OpenMath symbol for $(operator)"))
        end

        operators = Set{String}()
        for rule in get(document, "rules", Any[])
            _collect_operators!(operators, rule["pattern"])
            # A result and a constraint refer to the bindings the pattern made,
            # so a bare name among them is a reference, not an operator.
            bindings = _pattern_bindings(rule["pattern"])
            _collect_operators!(operators, rule["result"]; bindings)
            for constraint in get(rule, "constraints", Any[])
                _collect_constraint_operators!(operators, constraint; bindings)
            end
        end
        missing = sort!(collect(setdiff(operators, Set(String.(keys(semantics))))))
        isempty(missing) || throw(ArgumentError("Missing OpenMath semantics for: $(join(missing, ", "))"))
    end
    return nothing
end

"""
    UninterpretedHeads

Symbolic functions standing for OSR operations this package does not evaluate.

An operator a rule file declares carries an OpenMath symbol, so it denotes a
definite mathematical operation; when no implementation of it is reachable, what
is missing is the evaluation, not the meaning. Such a head becomes a symbolic
function here rather than in the module that loaded the rule file, so loading a
rule file introduces no name into the caller's scope and shadows nothing.
"""
module UninterpretedHeads
using SymbolicUtils
end

"""
    _DECLARED_HEADS

Names already declared in [`UninterpretedHeads`](@ref).

`isdefined` cannot answer this: that module imports `Base`, so `Int` and every
other `Base` name reads as defined there before anything is declared.
"""
const _DECLARED_HEADS = Set{Symbol}()

"""
    _rule_operators(documents)

Return every mathematical operator the given rule files apply.
"""
function _rule_operators(documents)
    operators = Set{String}()
    for document in documents
        for rule in get(document, "rules", Any[])
            _collect_operators!(operators, rule["pattern"])
            bindings = _pattern_bindings(rule["pattern"])
            _collect_operators!(operators, rule["result"]; bindings)
            for constraint in get(rule, "constraints", Any[])
                _collect_constraint_operators!(operators, constraint; bindings)
            end
        end
    end
    return operators
end

"""
    _head_is_operation(value)

Return whether `value` can stand in operator position.

A Julia type cannot: `Int` names an indefinite integral in the RUBI corpus and a
machine integer in `Base`, and building a term whose operation is `Base.Int`
raises the moment the rule fires — while no integral-aware code recognises it in
the meantime. Anything callable that is not a type is left alone, so a host can
still supply its own implementation of a head.
"""
_head_is_operation(value) = !(value isa Type)

"""
    _resolve_heads(documents, caller)

Return, for every operator the given rule files apply, the expression to place
in operator position.

A head the `caller` resolves to something that can act as an operation is used
as it stands, which is how a host supplies its own implementation. Every other
head is registered in [`UninterpretedHeads`](@ref) and referred to there, so it
denotes the declared operation and nothing else.
"""
function _resolve_heads(documents, caller::Module)
    heads = Dict{String,Any}()
    for operator in sort!(collect(_rule_operators(documents)))
        name = Symbol(operator)
        if isdefined(caller, name) && _head_is_operation(getfield(caller, name))
            heads[operator] = name
            continue
        end
        if !(name in _DECLARED_HEADS)
            # A variadic declaration: an OSR head's arity is whatever a rule uses.
            signature = Expr(:(::), Expr(:call, name, :(..)), :Number)
            Core.eval(UninterpretedHeads,
                      Expr(:macrocall, GlobalRef(SymbolicUtils, Symbol("@syms")),
                           LineNumberNode(0), signature))
            push!(_DECLARED_HEADS, name)
        end
        heads[operator] = GlobalRef(UninterpretedHeads, name)
    end
    return heads
end

"""
    @load_osr("path/to/rule.json")

Load an Open Symbolic Rules JSON file at compile-time and return a vector of `SymbolicUtils.jl` rules.
"""
macro load_osr(filepath)
    # The file path is relative to the caller's directory
    caller_dir = dirname(String(__source__.file))
    full_path = joinpath(caller_dir, filepath)

    # Read the JSON file at compile time
    data = JSON.parsefile(full_path)
    identity = get(data, "identity", get(data, "section", nothing))
    identity isa String || error("@load_osr requires a rule file with a string identity")
    _validate_openmath_semantics([data])
    heads = _resolve_heads([data], __module__)
    rule_exprs = _compile_rule_exprs(data["rules"]; identity=identity,
                                     semantics=data["semantics"], heads=heads,
                                     caller=__module__)

    # Return a block that constructs the array of rules
    return esc(Expr(:vect, rule_exprs...))
end

"""
    @load_osr_profile("repository/path"[, :profile])

Compile the complete default or named rewrite manifest of an OSR repository.
The repository path is relative to the caller source file.
"""
macro load_osr_profile(rootpath, profile=nothing)
    rootpath isa String || error("@load_osr_profile requires a literal repository path")
    profile_symbol = if profile === nothing
        nothing
    elseif profile isa QuoteNode && profile.value isa Symbol
        profile.value
    elseif profile isa Symbol
        profile
    else
        error("@load_osr_profile requires a literal Symbol profile")
    end

    caller_dir = dirname(String(__source__.file))
    full_root = joinpath(caller_dir, rootpath)
    
    documents = [JSON.parsefile(path) for path in rule_paths(full_root; profile=profile_symbol)]
    _validate_rule_identities(documents)
    _validate_openmath_semantics(documents)

    rule_exprs = Expr[]
    for data in documents
        identity = get(data, "identity", data["section"])
        append!(rule_exprs, _compile_rule_exprs(data["rules"]; identity=identity, semantics=data["semantics"]))
    end
    
    return esc(Expr(:vect, rule_exprs...))
end

# Exercise the rewriting paths at build time so that the first `simplify`,
# `prove`, or `select_piece` of a session does not pay for compiling them.
#
# The workload uses hand-written rules rather than a rule file, because what it
# needs to reach is the matcher, the dispatcher, and the rewriter — the code
# every rule set runs through, whatever the rules are.
@setup_workload begin
    @syms _w_x _w_p
    @syms _w_Pow(a, b) _w_Add(a, b) _w_Sin(a)

    @compile_workload begin
        rules = OSRRule[
            OSRRule("workload:1", "identity power", nothing,
                    @rule _w_Pow(~a, 1) => ~a),
            OSRRule("workload:2", "guarded zero power", nothing,
                    @rule _w_Pow(~a, 0) => 1 where is_nonzero(~a)),
            OSRRule("workload:3", "commutative additive identity", nothing,
                    @acrule _w_Add(~a, 0) => ~a),
        ]

        expression = _w_Add(_w_Pow(_w_Sin(_w_x), 1), 0)
        simplify(expression, rules)
        simplify(expression, rules; mode=:trace)
        simplify(_w_Pow(_w_x, 0), rules; assumptions=[IsNonzero(_w_x)])
        prove(expression, _w_Sin(_w_x), rules)

        FreeQ(expression, _w_x)
        free_variables(Lambda(_w_x, _w_Sin(_w_x)))
        osr_substitute(_w_Sin(_w_x), _w_x => _w_p)
        alpha_equivalent(Lambda(_w_x, _w_x), Lambda(_w_p, _w_p))
        select_piece(Piecewise([Piece(_w_x, IsPositive(_w_x)), Otherwise(_w_p)]))
        osr_number(_w_Pow(2, -1))
    end
end

end # module
