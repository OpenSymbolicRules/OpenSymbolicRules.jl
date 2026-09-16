"""
    FreeQ(expr, var)

Returns true if `expr` does not contain the variable `var`.
Equivalent to Mathematica's FreeQ. Used primarily to identify constants
relative to an integration or differentiation variable.
"""
function FreeQ(expr, var)
    if isequal(expr, var)
        return false
    elseif iscall(expr)
        return all(arg -> FreeQ(arg, var), arguments(expr))
    else
        return true
    end
end

"""
    is_integer(x)

Predicate to check if `x` is an integer.
"""
is_integer(x) = x isa Integer

"""
    is_numeric(x)

Predicate to check if `x` is a numeric constant.
"""
is_numeric(x) = x isa Number
