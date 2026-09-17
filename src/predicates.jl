using SymbolicUtils
using DomainSets
using IntervalSets

"""
    FreeQ(expr, var)

Returns true if `expr` has no free occurrence of `var`.  Equivalent to
Mathematica's FreeQ, and used primarily to identify constants relative to an
integration or differentiation variable.

Binders are respected: an occurrence bound by an enclosing `Lambda`, `Forall`,
or `Exists` is not an occurrence of the free variable, so `Lambda(x, Sin(x))`
is free of `x`.

Either side may be a collection.  A quantifier binds a list, so `var` may be the
whole binder and the predicate then asks about every variable it declares; and
RUBI writes `FreeQ[{a, b, m}, x]`, so `expr` may be a list whose every element
must be free of the variable.  When `var` is neither a variable nor a
collection, `expr` is searched for it structurally instead.
"""
function FreeQ(expr, var)
    variables = osr_collection(var)
    variables === nothing || return all(variable -> FreeQ(expr, variable), variables)

    name = _variable_name(var)
    name === nothing || return !occurs_free(expr, name)
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

Predicate to check if `x` is an integer, by value or by hypothesis.
"""
function is_integer(x)
    value = osr_number(x)
    value === nothing || return value isa Integer
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Integer
        return true
    end
    return entailed(x, :integer)
end

"""
    is_numeric(x)

Predicate to check if `x` denotes a numeric constant.  A closed arithmetic
expression such as `Add(1, 2)` is numeric; an expression containing a symbol is
not.
"""
is_numeric(x) = osr_number(x) !== nothing

"""
    NotEqual(a, b)

Predicate to check whether an inequality is established.  This is the OSR
spelling of RUBI's [`NeQ`](@ref) and shares its conservative semantics.
"""
NotEqual(a, b) = NeQ(a, b)

# Mathematical logic / Hypothesis predicates

@syms GreaterThan(a, b)
@syms LessThan(a, b)
@syms IsInteger(a)
@syms IsPositive(a)
@syms IsNegative(a)
@syms IsNonzero(a)

export GreaterThan, LessThan, IsInteger, IsPositive, IsNegative, IsNonzero

"""
    check_assumption(predicate)

Checks whether `predicate` is one of the hypotheses in scope, comparing it
literally.  The domain predicates use [`entailed`](@ref) instead, which also
accepts a hypothesis that merely implies the property.
"""
function check_assumption(predicate)
    ctx = get(task_local_storage(), :osr_assumptions, nothing)
    if ctx !== nothing
        for asm in ctx
            if isequal(asm, predicate)
                return true
            end
        end
    end
    return false
end

function is_positive(x)
    value = osr_number(x)
    value isa Real && return value > 0
    # A complex number has no sign, so its positivity is settled, not unknown.
    value === nothing || return false
    return entailed(x, :positive)
end

function is_negative(x)
    value = osr_number(x)
    value isa Real && return value < 0
    value === nothing || return false
    return entailed(x, :negative)
end

"""
    is_nonzero(x)

Returns whether `x` is provably nonzero.  For symbolic values, this requires
an explicit `IsNonzero(x)` assumption or a sign assumption; an unknown value
is deliberately not treated as nonzero.
"""
function is_nonzero(x)
    value = osr_number(x)
    value === nothing || return !iszero(value)
    return entailed(x, :nonzero)
end

function is_real(x)
    value = osr_number(x)
    value === nothing || return value isa Real
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Real
        return true
    end
    return entailed(x, :real)
end

function is_complex(x)
    # Every number is a complex number.
    osr_number(x) === nothing || return true
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Complex
        return true
    end
    return entailed(x, :complex)
end

export is_positive, is_negative, is_nonzero, FreeQ, is_integer, is_numeric, NotEqual, is_real, is_complex

"""
    assuming(f, assumptions...)

Executes a function `f` within a context where the provided `assumptions` hold true.
Useful for providing local hypotheses to the CAS.

Example:
```julia
assuming(x > 0) do
    simplify(Abs(x), rules)
end
```
"""
function assuming(f, assumptions...)
    current = get(task_local_storage(), :osr_assumptions, nothing)
    facts = _normalize_facts(assumptions)
    new_assumptions = current === nothing ? facts : vcat(current, facts)
    task_local_storage(f, :osr_assumptions, new_assumptions)
end

export assuming
