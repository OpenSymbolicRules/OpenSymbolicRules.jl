using SymbolicUtils
using SymbolicUtils: iscall, operation, arguments

"""
    differentiate(expression, variable, rules)

Differentiate `expression` with respect to `variable` using an OSR rule set.

`Derivative` binds its variable in a `Lambda`, as the OpenMath `fns1#lambda`
symbol prescribes, so this builds `Derivative(Lambda(variable, expression))`,
rewrites it with `rules`, and returns the body of the lambda it reaches. There
is no second expression tree: the argument and the answer are the one canonical
OSR representation throughout.

An operation the rule set cannot carry out stays a `Derivative` term. That is an
unevaluated expression rather than a closed form nobody reached, and
[`evaluated_derivative`](@ref) says which one came back.

`mode = :status` returns an [`OperationResult`](@ref) instead: the value beside
the reading it should be given, so an unevaluated operation cannot be mistaken
for a proved equality.

```jldoctest
julia> using OpenSymbolicRules, SymbolicUtils

julia> @syms x;

julia> rules = @load_osr_profile("../../Calculus");

julia> differentiate(Sin(x), x, rules)
Cos(x)
```
"""
function differentiate(expression, variable, rules::AbstractVector;
                       mode::Symbol=:fast, steps::Int=32)
    bound = _binder_variable(variable)
    reached = _lambda_body(_rewrite_and_reduce(Derivative(Lambda(bound, expression)),
                                               rules, steps), bound)
    return _read_as(:differentiate, reached, evaluated_derivative(reached), mode)
end

"""
    _read_as(operation, reached, evaluated, mode)

Return what the caller asked for: the expression, or the expression beside the
reading it should be given.

`mode` follows `simplify`: `:fast` hands back the value alone, and `:status`
hands back an [`OperationResult`](@ref), which is what keeps an unevaluated
operation from being read as a proved equality.
"""
function _read_as(operation::Symbol, reached, evaluated::Bool, mode::Symbol)
    mode === :fast && return reached
    mode === :status && return _operation_result(operation, reached, !evaluated)
    throw(ArgumentError("unknown mode: $(mode); expected :fast or :status"))
end

"""
    _rewrite_and_reduce(expression, rules, steps)

Rewrite `expression` and reduce the applications the rewriting leaves, until
neither changes it.

The two need each other. A structural rule returns a lambda whose body applies
the lambdas the base rules return, so reduction cannot run until the rewriting
has produced them; and the rewriting cannot continue past an application until
reduction has collapsed it. Alternating is what lets a rule set differentiate a
sum term by term.
"""
function _rewrite_and_reduce(expression, rules::AbstractVector, steps::Int)
    current = expression
    for _ in 1:steps
        next = beta_reduce(simplify(current, rules))
        isequal(next, current) && return current
        current = next
    end
    return current
end

"""
    limit(expression, variable, point, rules; direction=BothSides)

Take the limit of `expression` as `variable` approaches `point`, using an OSR
rule set.

`Limit` carries its point, its approach, and a lambda-bound expression, so this
assembles `Limit(point, direction, Lambda(variable, expression))` and rewrites
it. The arguments are taken in the order a reader expects rather than the order
the term stores them.

A limit the rule set does not cover stays a `Limit` term, which is the honest
answer: no value was established.
"""
function limit(expression, variable, point, rules::AbstractVector;
               direction=BothSides, mode::Symbol=:fast, steps::Int=32)
    bound = _binder_variable(variable)
    reached = _rewrite_and_reduce(Limit(point, direction, Lambda(bound, expression)),
                                  rules, steps)
    return _read_as(:limit, reached, evaluated_limit(reached), mode)
end

"""
    evaluated_derivative(expression)

Return whether `expression` holds no `Derivative` still waiting to be carried
out.
"""
evaluated_derivative(expression) = !_mentions_head(expression, :Derivative)

"""
    evaluated_limit(expression)

Return whether `expression` holds no `Limit` still waiting to be taken.
"""
evaluated_limit(expression) = !_mentions_head(expression, :Limit)

"""
    _binder_variable(variable)

Return the symbol a binder should bind for `variable`, accepting either a
`SymbolicUtils` variable or its name.
"""
function _binder_variable(variable)
    name = _variable_name(variable)
    name === nothing &&
        throw(ArgumentError("a calculus operation binds a variable, not $(variable)"))
    return variable isa Symbol ? variable : variable
end

"""
    _lambda_body(expression, bound)

Return the body of `expression` when it is the lambda `bound` was bound in, and
`expression` itself otherwise — which is what an unevaluated derivative looks
like.
"""
function _lambda_body(expression, bound)
    iscall(expression) || return expression
    _operation_name(operation(expression)) === :Lambda || return expression
    operands = arguments(expression)
    length(operands) == 2 || return expression
    isequal(_variable_name(operands[1]), _variable_name(bound)) || return expression
    return operands[2]
end

function _mentions_head(expression, name::Symbol)
    expression = _literal(expression)
    iscall(expression) || return false
    _operation_name(operation(expression)) === name && return true
    return any(argument -> _mentions_head(argument, name), arguments(expression))
end

export differentiate, limit, evaluated_derivative, evaluated_limit
