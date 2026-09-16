using SymbolicUtils
using DomainSets
using IntervalSets

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

Predicate to check if `x` is an integer, by value or by hypothesis.
"""
function is_integer(x)
    value = osr_number(x)
    value === nothing || return value isa Integer
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Integer
        return true
    end
    check_assumption(ElementOf(x, Integers())) || check_assumption(ElementOf(x, Int))
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

Checks if `predicate` is in the `task_local_storage(:osr_assumptions)`.
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
    # Check both old-style predicates and DomainSets
    check_assumption(IsPositive(x)) || 
    check_assumption(GreaterThan(x, 0)) ||
    check_assumption(ElementOf(x, 0..Inf)) ||
    check_assumption(ElementOf(x, OpenInterval(0, Inf))) ||
    check_assumption(ElementOf(x, HalfLine()))
end

function is_negative(x)
    value = osr_number(x)
    value isa Real && return value < 0
    value === nothing || return false
    check_assumption(IsNegative(x)) || 
    check_assumption(LessThan(x, 0)) ||
    check_assumption(ElementOf(x, -Inf..0)) ||
    check_assumption(ElementOf(x, OpenInterval(-Inf, 0))) ||
    check_assumption(ElementOf(x, NegativeHalfLine()))
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
    check_assumption(IsNonzero(x)) || is_positive(x) || is_negative(x)
end

function is_real(x)
    value = osr_number(x)
    value === nothing || return value isa Real
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Real
        return true
    end
    check_assumption(ElementOf(x, Reals())) || check_assumption(ElementOf(x, Real))
end

function is_complex(x)
    # Every number is a complex number.
    osr_number(x) === nothing || return true
    if x isa SymbolicUtils.BasicSymbolic && SymbolicUtils.symtype(x) <: Complex
        return true
    end
    check_assumption(ElementOf(x, ComplexPlane())) || check_assumption(ElementOf(x, Complex)) || is_real(x)
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
    new_assumptions = current === nothing ? collect(assumptions) : vcat(current, collect(assumptions))
    task_local_storage(f, :osr_assumptions, new_assumptions)
end

export assuming
