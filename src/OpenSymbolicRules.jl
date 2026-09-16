module OpenSymbolicRules

using JSON
using SymbolicUtils
using SymbolicUtils: @rule, Sym, Term
using SymbolicUtils: iscall, arguments

include("predicates.jl")
include("simplify.jl")
include("equations.jl")
include("domains.jl")
include("bridge.jl")
include("manifests.jl")
include("heads.jl")

export @load_osr, @load_osr_profile, rule_paths, load_inference_profile, OSRInference, OSRRule
export FreeQ, is_integer, is_numeric, NotEqual
export build_simplifier

const _ASSOCIATIVE_OPERATORS = Set(["Add", "Multiply", "And", "Or"])

"""
    osr_to_expr(node)

Recursively parse an OSR JSON node into a Julia expression for SymbolicUtils.
"""
function osr_to_expr(node)
    if node isa String
        if startswith(node, "~")
            # Pattern variable
            return Expr(:call, :~, Symbol(node[2:end]))
        elseif endswith(node, "_")
            # OSR v0.1 wildcard syntax
            return Expr(:call, :~, Symbol(node[1:end-1]))
        elseif node == "True"
            return true
        elseif node == "False"
            return false
        else
            # Normal symbol/function
            return Symbol(node)
        end
    elseif node isa AbstractArray
        if length(node) == 3 && node[1] isa String && node[1] in ("Forall", "Exists")
            variables = node[2]
            variables isa AbstractArray || throw(ArgumentError("Quantifier variables must be an array"))
            all(variable -> variable isa String, variables) || throw(ArgumentError("Quantifier variables must be strings"))
            bound_variables = Expr(:vect, [QuoteNode(Symbol(variable)) for variable in variables]...)
            return Expr(:call, Symbol(node[1]), bound_variables, osr_to_expr(node[3]))
        end
        # Function call, e.g. ["Multiply", "x", "y"] -> Multiply(x, y)
        op = Symbol(node[1])
        args = map(osr_to_expr, node[2:end])
        if node[1] in _ASSOCIATIVE_OPERATORS && length(args) > 2
            return reduce((left, right) -> Expr(:call, op, left, right), args)
        end
        return Expr(:call, op, args...)
    else
        # Literals like numbers
        return node
    end
end

function _compile_rule_exprs(rules_json; section::AbstractString="unknown")
    rule_exprs = Expr[]
    seen_ids = Set{Int}()
    for rule in rules_json
        id = get(rule, "id", nothing)
        id isa Integer || throw(ArgumentError("Every OSR rule must have an integer id"))
        id in seen_ids && throw(ArgumentError("Duplicate OSR rule id $(id) in section $(section)"))
        push!(seen_ids, id)

        pattern = osr_to_expr(rule["pattern"])
        result = osr_to_expr(rule["result"])
        constraints_json = get(rule, "constraints", [])

        rewrite = if isempty(constraints_json)
            Expr(:macrocall, GlobalRef(SymbolicUtils, Symbol("@rule")), LineNumberNode(0), :($pattern => $result))
        else
            condition_expressions = Expr[]
            for constraint in constraints_json
                pred_str = constraint[1]
                predicate = if pred_str == "PositiveQ"
                    :is_positive
                elseif pred_str == "NegativeQ"
                    :is_negative
                elseif pred_str == "IntegerQ"
                    :is_integer
                elseif pred_str == "RealQ"
                    :is_real
                elseif pred_str == "ComplexQ"
                    :is_complex
                elseif pred_str == "NumericQ"
                    :is_numeric
                elseif pred_str == "NotEqual"
                    :NotEqual
                elseif pred_str == "FreeQ"
                    :FreeQ
                else
                    Symbol(pred_str)
                end
                arguments = map(osr_to_expr, constraint[2:end])
                push!(condition_expressions, Expr(:call, predicate, arguments...))
            end
            condition = length(condition_expressions) == 1 ? condition_expressions[1] : Expr(:&&, condition_expressions...)
            Expr(:macrocall, GlobalRef(SymbolicUtils, Symbol("@rule")), LineNumberNode(0), :($pattern => $result where $condition))
        end
        name = "$(section):$(id)"
        description = get(rule, "description", nothing)
        push!(rule_exprs, :(OSRRule($name, $description, $rewrite)))
    end
    return rule_exprs
end

function _validate_rule_identities(documents)
    identities = Set{String}()
    for document in documents
        section = get(document, "section", nothing)
        section isa String || throw(ArgumentError("Every OSR rule file must have a string section"))
        for rule in get(document, "rules", Any[])
            id = get(rule, "id", nothing)
            id isa Integer || throw(ArgumentError("Every OSR rule must have an integer id"))
            identity = "$(section):$(id)"
            identity in identities && throw(ArgumentError("Duplicate OSR rule identity $(identity)"))
            push!(identities, identity)
        end
    end
    return nothing
end

const _OPENMATH_SYMBOL = r"^openmath:[A-Za-z][A-Za-z0-9_]*#[A-Za-z][A-Za-z0-9_]*$"

function _collect_operators!(operators::Set{String}, expression)
    expression isa AbstractArray || return nothing
    isempty(expression) && throw(ArgumentError("OSR expressions cannot be empty arrays"))
    operator = first(expression)
    operator isa String || throw(ArgumentError("OSR expression operators must be strings"))
    push!(operators, operator)

    if operator in ("Forall", "Exists")
        length(expression) == 3 || throw(ArgumentError("OSR quantifiers require variables and a body"))
        _collect_operators!(operators, expression[3])
    else
        for argument in expression[2:end]
            _collect_operators!(operators, argument)
        end
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
            _collect_operators!(operators, rule["result"])
            for constraint in get(rule, "constraints", Any[])
                constraint isa AbstractArray && !isempty(constraint) || throw(ArgumentError("OSR constraints must be non-empty arrays"))
                for argument in constraint[2:end]
                    _collect_operators!(operators, argument)
                end
            end
        end
        missing = sort!(collect(setdiff(operators, Set(String.(keys(semantics))))))
        isempty(missing) || throw(ArgumentError("Missing OpenMath semantics for: $(join(missing, ", "))"))
    end
    return nothing
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
    section = get(data, "section", nothing)
    section isa String || error("@load_osr requires a rule file with a string section")
    _validate_openmath_semantics([data])
    rule_exprs = _compile_rule_exprs(data["rules"]; section=section)
    
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
        section = data["section"]
        append!(rule_exprs, _compile_rule_exprs(data["rules"]; section=section))
    end
    
    return esc(Expr(:vect, rule_exprs...))
end

end # module
