"""Exact sparse multivariate polynomial primitives for algebraic backends."""
struct SparsePolynomial
    variables::Tuple{Vararg{Symbol}}
    terms::Dict{Tuple{Vararg{Int}},Rational{BigInt}}

    function SparsePolynomial(variables::Tuple{Vararg{Symbol}}, terms::AbstractDict)
        length(unique(variables)) == length(variables) ||
            throw(ArgumentError("polynomial variables must be unique"))
        normalized = Dict{Tuple{Vararg{Int}},Rational{BigInt}}()
        for (exponents, coefficient) in terms
            exponent = Tuple(Int.(exponents))
            length(exponent) == length(variables) ||
                throw(ArgumentError("monomial exponent length does not match variables"))
            all(>=(0), exponent) || throw(ArgumentError("monomial exponents must be non-negative"))
            value = Rational{BigInt}(coefficient)
            iszero(value) && continue
            normalized[exponent] = get(normalized, exponent, zero(value)) + value
            iszero(normalized[exponent]) && delete!(normalized, exponent)
        end
        new(variables, normalized)
    end
end

SparsePolynomial(variables::AbstractVector{Symbol}, terms::AbstractDict) =
    SparsePolynomial(Tuple(variables), terms)

Base.iszero(polynomial::SparsePolynomial) = isempty(polynomial.terms)
Base.:(==)(left::SparsePolynomial, right::SparsePolynomial) =
    left.variables == right.variables && left.terms == right.terms
Base.hash(polynomial::SparsePolynomial, hash_value::UInt) =
    hash((polynomial.variables, polynomial.terms), hash(hash(:SparsePolynomial, hash_value)))

function _same_ring(left::SparsePolynomial, right::SparsePolynomial)
    left.variables == right.variables || throw(ArgumentError("polynomials belong to different rings"))
end

function Base.:+(left::SparsePolynomial, right::SparsePolynomial)
    _same_ring(left, right)
    terms = copy(left.terms)
    for (exponent, coefficient) in right.terms
        terms[exponent] = get(terms, exponent, zero(coefficient)) + coefficient
        iszero(terms[exponent]) && delete!(terms, exponent)
    end
    SparsePolynomial(left.variables, terms)
end

Base.:-(polynomial::SparsePolynomial) =
    SparsePolynomial(polynomial.variables, Dict(exponent => -coefficient for (exponent, coefficient) in polynomial.terms))
Base.:-(left::SparsePolynomial, right::SparsePolynomial) = left + (-right)

function _scale_monomial(polynomial::SparsePolynomial, exponent, coefficient)
    SparsePolynomial(polynomial.variables,
        Dict(Tuple(left + right for (left, right) in zip(monomial, exponent)) => coefficient * value
             for (monomial, value) in polynomial.terms))
end

function _monomial_divides(divisor, dividend)
    all(left <= right for (left, right) in zip(divisor, dividend))
end

_monomial_quotient(dividend, divisor) = Tuple(left - right for (left, right) in zip(dividend, divisor))
_monomial_lcm(left, right) = Tuple(max(a, b) for (a, b) in zip(left, right))

function _monomial_greater(left, right, ordering::Symbol)
    ordering in (:lex, :grlex, :grevlex) || throw(ArgumentError("unknown monomial ordering `$ordering`"))
    ordering != :lex && sum(left) != sum(right) && return sum(left) > sum(right)
    if ordering == :grevlex
        for index in reverse(eachindex(left))
            left[index] == right[index] || return left[index] < right[index]
        end
    else
        for index in eachindex(left)
            left[index] == right[index] || return left[index] > right[index]
        end
    end
    false
end

function leading_monomial(polynomial::SparsePolynomial, ordering::Symbol=:grevlex)
    iszero(polynomial) && throw(ArgumentError("the zero polynomial has no leading monomial"))
    reduce((left, right) -> _monomial_greater(left, right, ordering) ? left : right,
           keys(polynomial.terms))
end

leading_coefficient(polynomial::SparsePolynomial, ordering::Symbol=:grevlex) =
    polynomial.terms[leading_monomial(polynomial, ordering)]

function spoly(left::SparsePolynomial, right::SparsePolynomial; ordering::Symbol=:grevlex)
    _same_ring(left, right)
    (iszero(left) || iszero(right)) && return SparsePolynomial(left.variables, Dict())
    left_monomial = leading_monomial(left, ordering)
    right_monomial = leading_monomial(right, ordering)
    lcm_monomial = _monomial_lcm(left_monomial, right_monomial)
    left_multiplier = _monomial_quotient(lcm_monomial, left_monomial)
    right_multiplier = _monomial_quotient(lcm_monomial, right_monomial)
    _scale_monomial(left, left_multiplier, inv(leading_coefficient(left, ordering))) -
        _scale_monomial(right, right_multiplier, inv(leading_coefficient(right, ordering)))
end

function normal_form(polynomial::SparsePolynomial, divisors::AbstractVector{<:SparsePolynomial}; ordering::Symbol=:grevlex)
    all(divisor -> divisor.variables == polynomial.variables, divisors) ||
        throw(ArgumentError("all divisors must belong to the polynomial ring"))
    pending = polynomial
    remainder = SparsePolynomial(polynomial.variables, Dict())
    while !iszero(pending)
        monomial = leading_monomial(pending, ordering)
        coefficient = pending.terms[monomial]
        divisor = findfirst(candidate -> !iszero(candidate) &&
                           _monomial_divides(leading_monomial(candidate, ordering), monomial), divisors)
        if divisor === nothing
            remainder += SparsePolynomial(polynomial.variables, Dict(monomial => coefficient))
            pending -= SparsePolynomial(polynomial.variables, Dict(monomial => coefficient))
        else
            candidate = divisors[divisor]
            quotient = _monomial_quotient(monomial, leading_monomial(candidate, ordering))
            factor = coefficient / leading_coefficient(candidate, ordering)
            pending -= _scale_monomial(candidate, quotient, factor)
        end
    end
    remainder
end

function _monic(polynomial::SparsePolynomial, ordering::Symbol)
    iszero(polynomial) && return polynomial
    _scale_monomial(polynomial, ntuple(_ -> 0, length(polynomial.variables)),
                    inv(leading_coefficient(polynomial, ordering)))
end

function _coprime_monomials(left, right)
    all(min(a, b) == 0 for (a, b) in zip(left, right))
end

"""
    groebner_basis(generators; ordering=:grevlex)

Compute a reduced Gröbner basis with Buchberger's algorithm over the rational
coefficient field. This pure-Julia reference implementation prioritizes exact
results and traceable invariants over large-system performance.
"""
function groebner_basis(generators::AbstractVector{<:SparsePolynomial}; ordering::Symbol=:grevlex)
    isempty(generators) && return SparsePolynomial[]
    variables = first(generators).variables
    all(polynomial -> polynomial.variables == variables, generators) ||
        throw(ArgumentError("all generators must belong to the polynomial ring"))
    basis = [_monic(polynomial, ordering) for polynomial in generators if !iszero(polynomial)]
    pairs = [(left, right) for left in eachindex(basis) for right in left + 1:length(basis)]
    while !isempty(pairs)
        left, right = popfirst!(pairs)
        left_monomial = leading_monomial(basis[left], ordering)
        right_monomial = leading_monomial(basis[right], ordering)
        _coprime_monomials(left_monomial, right_monomial) && continue
        remainder = normal_form(spoly(basis[left], basis[right]; ordering), basis; ordering)
        iszero(remainder) && continue
        push!(basis, _monic(remainder, ordering))
        newest = lastindex(basis)
        append!(pairs, ((index, newest) for index in firstindex(basis):newest - 1))
    end
    reduced = SparsePolynomial[]
    for (index, polynomial) in enumerate(basis)
        remainder = normal_form(polynomial, [basis[other] for other in eachindex(basis) if other != index]; ordering)
        iszero(remainder) || push!(reduced, _monic(remainder, ordering))
    end
    unique(reduced)
end

ideal_membership(polynomial::SparsePolynomial, basis::AbstractVector{<:SparsePolynomial}; ordering::Symbol=:grevlex) =
    iszero(normal_form(polynomial, basis; ordering))

function _constant_polynomial(variables, value)
    SparsePolynomial(variables, Dict(ntuple(_ -> 0, length(variables)) => value))
end

function _multiply(left::SparsePolynomial, right::SparsePolynomial)
    _same_ring(left, right)
    terms = Dict{Tuple{Vararg{Int}},Rational{BigInt}}()
    for (left_exponent, left_coefficient) in left.terms,
        (right_exponent, right_coefficient) in right.terms
        exponent = Tuple(a + b for (a, b) in zip(left_exponent, right_exponent))
        terms[exponent] = get(terms, exponent, zero(left_coefficient)) +
                          left_coefficient * right_coefficient
        iszero(terms[exponent]) && delete!(terms, exponent)
    end
    SparsePolynomial(left.variables, terms)
end

function _power(polynomial::SparsePolynomial, exponent::Integer)
    exponent >= 0 || throw(ArgumentError("polynomial exponents must be non-negative integers"))
    result = _constant_polynomial(polynomial.variables, 1)
    factor = polynomial
    remaining = exponent
    while remaining > 0
        isodd(remaining) && (result = _multiply(result, factor))
        remaining = div(remaining, 2)
        remaining > 0 && (factor = _multiply(factor, factor))
    end
    result
end

function _exact_coefficient(expression)
    try
        Rational{BigInt}(SymbolicUtils.unwrap_const(expression))
    catch error
        error isa MethodError || rethrow()
        nothing
    end
end

function _to_sparse_polynomial(expression, variables::Tuple{Vararg{Symbol}})
    coefficient = _exact_coefficient(expression)
    coefficient !== nothing && return _constant_polynomial(variables, coefficient)

    if !SymbolicUtils.iscall(expression)
        name = try
            SymbolicUtils.getname(expression)
        catch error
            error isa ArgumentError || rethrow()
            nothing
        end
        index = findfirst(==(name), variables)
        index === nothing && throw(ArgumentError("expression contains a variable outside the polynomial ring"))
        exponent = ntuple(position -> position == index ? 1 : 0, length(variables))
        return SparsePolynomial(variables, Dict(exponent => 1))
    end

    operator = SymbolicUtils.operation(expression)
    operands = SymbolicUtils.arguments(expression)
    if operator === +
        return foldl(+, (_to_sparse_polynomial(operand, variables) for operand in operands);
                     init=SparsePolynomial(variables, Dict()))
    elseif operator === *
        return foldl(_multiply, (_to_sparse_polynomial(operand, variables) for operand in operands);
                     init=_constant_polynomial(variables, 1))
    elseif operator === (^) && length(operands) == 2
        exponent = _exact_coefficient(operands[2])
        exponent !== nothing && denominator(exponent) == 1 ||
            throw(ArgumentError("polynomial exponents must be exact integers"))
        return _power(_to_sparse_polynomial(operands[1], variables), numerator(exponent))
    end
    throw(ArgumentError("expression is not a polynomial over the requested ring"))
end

"""
    to_sparse_polynomial(expression, variables) -> SparsePolynomial

Convert a `SymbolicUtils` expression to an exact polynomial over `ℚ`. Variables
are explicitly named to prevent accidental conversion of parameters or
non-polynomial subexpressions. Only addition, multiplication, non-negative
integer powers, and exact rational coefficients are admitted.
"""
to_sparse_polynomial(expression, variables::AbstractVector{Symbol}) =
    _to_sparse_polynomial(expression, Tuple(variables))

"""
    to_symbolic_polynomial(polynomial, variables)

Rebuild a `SymbolicUtils` expression from an exact sparse polynomial. The map
must associate every polynomial variable name with its symbolic expression.
"""
function to_symbolic_polynomial(polynomial::SparsePolynomial, variables::AbstractDict{Symbol})
    all(variable -> haskey(variables, variable), polynomial.variables) ||
        throw(ArgumentError("the symbolic variable map does not cover the polynomial ring"))
    result = 0
    for (exponents, coefficient) in polynomial.terms
        monomial = coefficient
        for (variable, exponent) in zip(polynomial.variables, exponents)
            exponent == 0 && continue
            monomial *= variables[variable]^exponent
        end
        result += monomial
    end
    result
end

# Keep low-level leading-term and S-polynomial primitives qualified.  They are
# useful for inspecting an algorithm, but are not part of the everyday API.
export SparsePolynomial, normal_form, groebner_basis, ideal_membership
export to_sparse_polynomial, to_symbolic_polynomial
