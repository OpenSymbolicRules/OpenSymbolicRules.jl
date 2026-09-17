using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments, issym, symtype, vartype, metadata, maketerm

"""
    _BINDER_HEADS

Canonical OSR heads that introduce a lexical scope.  `Lambda` binds one
variable, `Forall` and `Exists` bind a vector of variable names.  Every other
binding construct — an integral, a sum, a product, a derivative — carries its
bound variable inside a `Lambda`, as the OpenMath `fns1#lambda` symbol
prescribes, so it needs no separate entry.
"""
const _BINDER_HEADS = (:Lambda, :Forall, :Exists)

"""
    _variable_name(value)

Return the name of a variable, whether it is written as a Julia `Symbol` — the
form quantifier binders use — or as a `SymbolicUtils` symbol.  Anything else
has no name.
"""
function _variable_name(value)
    value isa Symbol && return value
    value = _literal(value)
    value isa SymbolicUtils.BasicSymbolic && issym(value) && return nameof(value)
    return nothing
end

function _variable_names(value)
    name = _variable_name(value)
    name === nothing || return [name]
    value = _literal(value)
    value isa AbstractVector && !isempty(value) || return nothing
    names = Symbol[]
    for element in value
        element_name = _variable_name(element)
        element_name === nothing && return nothing
        push!(names, element_name)
    end
    return names
end

"""
    bound_variables(expr)

Return the variable names the binder term `expr` introduces, or `nothing` when
`expr` binds nothing.
"""
function bound_variables(expr)
    iscall(expr) || return nothing
    _operation_name(operation(expr)) in _BINDER_HEADS || return nothing
    operands = arguments(expr)
    length(operands) == 2 || return nothing
    return _variable_names(operands[1])
end

"""
    binder_body(expr)

Return the body a binder term scopes over.
"""
binder_body(expr) = arguments(expr)[2]

"""
    free_variables(expr)

Return the names that occur free in `expr`.  A name bound by an enclosing
`Lambda`, `Forall`, or `Exists` is not free.

```jldoctest
julia> using OpenSymbolicRules, SymbolicUtils

julia> @syms x y;

julia> OpenSymbolicRules.free_variables(Lambda(x, Add(x, y)))
Set{Symbol} with 1 element:
  :y
```
"""
free_variables(expr) = _free_variables!(Set{Symbol}(), expr)

function _free_variables!(names::Set{Symbol}, expr)
    expr = _literal(expr)
    if expr isa AbstractVector
        # A collection argument, such as a piecewise branch list, is part of the
        # expression, so its variables are free in it.
        for element in expr
            _free_variables!(names, element)
        end
        return names
    end
    if !iscall(expr)
        name = _variable_name(expr)
        name === nothing || push!(names, name)
        return names
    end

    bound = bound_variables(expr)
    if bound === nothing
        for operand in arguments(expr)
            _free_variables!(names, operand)
        end
        return names
    end

    body_names = _free_variables!(Set{Symbol}(), binder_body(expr))
    setdiff!(body_names, bound)
    return union!(names, body_names)
end

"""
    occurs_free(expr, name)

Return whether `name` occurs free in `expr`.  This answers the single question
[`FreeQ`](@ref) asks without materialising the whole free-variable set, and it
stops at the first free occurrence.
"""
occurs_free(expr, name::Symbol) = _occurs_free(expr, name)

function _occurs_free(expr, name::Symbol)
    expr = _literal(expr)
    expr isa AbstractVector && return any(element -> _occurs_free(element, name), expr)
    iscall(expr) || return _variable_name(expr) === name

    bound = bound_variables(expr)
    bound === nothing || return !(name in bound) && _occurs_free(binder_body(expr), name)
    return any(operand -> _occurs_free(operand, name), arguments(expr))
end

"""
    _fresh_name(base, taken)

Return a variant of `base` that is not in `taken`.
"""
function _fresh_name(base::Symbol, taken)
    index = 1
    while true
        candidate = Symbol(base, index)
        candidate in taken || return candidate
        index += 1
    end
end

_rename_variable(variable::Symbol, name::Symbol) = name

function _rename_variable(variable, name::Symbol)
    variable = _literal(variable)
    return SymbolicUtils.Sym{vartype(variable)}(name; type=symtype(variable))
end

_rebuild(expr, operands) =
    maketerm(typeof(expr), operation(expr), operands, metadata(expr))

_binder_declaration(expr) = _literal(arguments(expr)[1])

function _rebuild_binder(expr, variables, body)
    declaration = _binder_declaration(expr)
    renamed = declaration isa AbstractVector ? variables : only(variables)
    return _rebuild(expr, [renamed, body])
end

"""
    _alpha_rename(expr, renamings)

Rename the variables of a binder term according to `renamings`, a map from the
current name to the new one.
"""
function _alpha_rename(expr, renamings::AbstractDict{Symbol,Symbol})
    declaration = _binder_declaration(expr)
    originals = declaration isa AbstractVector ? collect(declaration) : [declaration]
    variables = map(originals) do variable
        name = _variable_name(variable)
        target = get(renamings, name, name)
        target === name ? variable : _rename_variable(variable, target)
    end

    body = binder_body(expr)
    for (index, variable) in enumerate(originals)
        name = _variable_name(variable)
        target = get(renamings, name, name)
        target === name && continue
        body = _substitute(body, name, variables[index], Set([target]))
    end
    return _rebuild_binder(expr, variables, body)
end

"""
    osr_substitute(expr, variable => replacement)

Substitute `replacement` for the free occurrences of `variable` in `expr`.  The
substitution is capture-avoiding: a binder whose variable occurs free in
`replacement` is alpha-renamed first, so the replacement keeps referring to the
same variable it did outside the binder.

```jldoctest
julia> using OpenSymbolicRules, SymbolicUtils

julia> @syms x y;

julia> OpenSymbolicRules.osr_substitute(Lambda(y, Add(x, y)), x => y)
Lambda(y1, Add(y, y1))
```
"""
function osr_substitute(expr, substitution::Pair)
    variable, replacement = substitution
    name = _variable_name(variable)
    name === nothing && throw(ArgumentError("Only a variable can be substituted for"))
    return _substitute(expr, name, replacement, free_variables(replacement))
end

function _substitute(expr, name::Symbol, replacement, replacement_free::Set{Symbol})
    expr = _literal(expr)
    if expr isa AbstractVector
        return map(element -> _substitute(element, name, replacement, replacement_free), expr)
    end
    if !iscall(expr)
        return _variable_name(expr) === name ? replacement : expr
    end

    bound = bound_variables(expr)
    if bound === nothing
        operands = map(arguments(expr)) do operand
            _substitute(operand, name, replacement, replacement_free)
        end
        return _rebuild(expr, operands)
    end

    # The binder shadows the variable, so `expr` has no free occurrence of it.
    name in bound && return expr

    captured = filter(variable -> variable in replacement_free, bound)
    if !isempty(captured)
        taken = union(replacement_free, free_variables(expr), Set(bound), Set([name]))
        renamings = Dict{Symbol,Symbol}()
        for variable in captured
            fresh = _fresh_name(variable, taken)
            renamings[variable] = fresh
            push!(taken, fresh)
        end
        expr = _alpha_rename(expr, renamings)
    end

    body = _substitute(binder_body(expr), name, replacement, replacement_free)
    declaration = _binder_declaration(expr)
    variables = declaration isa AbstractVector ? collect(declaration) : [declaration]
    return _rebuild_binder(expr, variables, body)
end

"""
    alpha_equivalent(left, right)

Return whether two expressions are equal up to a consistent renaming of their
bound variables.  Free variables are compared by name.

```jldoctest
julia> using OpenSymbolicRules, SymbolicUtils

julia> @syms x y;

julia> OpenSymbolicRules.alpha_equivalent(Lambda(x, Sin(x)), Lambda(y, Sin(y)))
true
```
"""
alpha_equivalent(left, right) = _alpha_equivalent(left, right, Dict{Symbol,Int}(), Dict{Symbol,Int}(), 0)

function _alpha_equivalent(left, right, left_depths, right_depths, depth)
    left, right = _literal(left), _literal(right)

    if left isa AbstractVector || right isa AbstractVector
        left isa AbstractVector && right isa AbstractVector || return false
        length(left) == length(right) || return false
        return all(eachindex(left)) do index
            _alpha_equivalent(left[index], right[index], left_depths, right_depths, depth)
        end
    end

    left_call, right_call = iscall(left), iscall(right)
    left_call == right_call || return false

    if !left_call
        left_name, right_name = _variable_name(left), _variable_name(right)
        if left_name === nothing || right_name === nothing
            return isequal(left, right)
        end
        left_depth = get(left_depths, left_name, nothing)
        right_depth = get(right_depths, right_name, nothing)
        # A bound name matches a bound name introduced at the same depth; a free
        # name matches only itself.
        left_depth === right_depth || return false
        return left_depth === nothing ? left_name === right_name : true
    end

    isequal(operation(left), operation(right)) || return false

    left_bound, right_bound = bound_variables(left), bound_variables(right)
    if left_bound === nothing || right_bound === nothing
        left_bound === right_bound || return false
        left_operands, right_operands = arguments(left), arguments(right)
        length(left_operands) == length(right_operands) || return false
        return all(eachindex(left_operands)) do index
            _alpha_equivalent(left_operands[index], right_operands[index], left_depths, right_depths, depth)
        end
    end

    length(left_bound) == length(right_bound) || return false
    inner_left = copy(left_depths)
    inner_right = copy(right_depths)
    for (index, (left_name, right_name)) in enumerate(zip(left_bound, right_bound))
        inner_left[left_name] = depth + index
        inner_right[right_name] = depth + index
    end
    return _alpha_equivalent(binder_body(left), binder_body(right), inner_left, inner_right, depth + length(left_bound))
end

export bound_variables, binder_body, free_variables, occurs_free, osr_substitute, alpha_equivalent
