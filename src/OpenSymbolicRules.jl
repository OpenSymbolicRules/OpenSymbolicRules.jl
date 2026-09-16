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

export @load_osr, @load_osr_profile, rule_paths, load_inference_profile, OSRInference
export FreeQ, is_integer, is_numeric, NotEqual
export build_simplifier, osr_simplify

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
        # Function call, e.g. ["Mul", "x", "y"] -> Mul(x, y)
        op = Symbol(node[1])
        args = map(osr_to_expr, node[2:end])
        return Expr(:call, op, args...)
    else
        # Literals like numbers
        return node
    end
end

function _compile_rule_exprs(rules_json)
    rule_exprs = Expr[]
    for rule in rules_json
        pattern = osr_to_expr(rule["pattern"])
        result = osr_to_expr(rule["result"])
        constraints_json = get(rule, "constraints", [])

        if isempty(constraints_json)
            push!(rule_exprs, :(@rule($pattern => $result)))
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
            push!(rule_exprs, :(@rule($pattern => $result where $condition)))
        end
    end
    return rule_exprs
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
    rule_exprs = _compile_rule_exprs(data["rules"])
    
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
    
    rule_exprs = Expr[]
    for path in rule_paths(full_root; profile=profile_symbol)
        append!(rule_exprs, _compile_rule_exprs(JSON.parsefile(path)["rules"]))
    end
    
    return esc(Expr(:vect, rule_exprs...))
end

end # module
