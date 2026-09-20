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

function _univariate_coefficients(polynomial::SparsePolynomial)
    length(polynomial.variables) == 1 || throw(ArgumentError("resultant currently requires a univariate polynomial ring"))
    iszero(polynomial) && return Rational{BigInt}[]
    degree = maximum(first(exponent) for exponent in keys(polynomial.terms))
    [get(polynomial.terms, (power,), zero(Rational{BigInt})) for power in degree:-1:0]
end

function _determinant(matrix::Matrix{Rational{BigInt}})
    size(matrix, 1) == size(matrix, 2) || throw(ArgumentError("determinant requires a square matrix"))
    size(matrix, 1) == 0 && return one(Rational{BigInt})
    size(matrix, 1) == 1 && return matrix[1, 1]
    sum((isodd(column) ? 1 : -1) * matrix[1, column] *
        _determinant(matrix[2:end, [index for index in axes(matrix, 2) if index != column]])
        for column in axes(matrix, 2))
end

"""Return the exact Sylvester resultant of two univariate rational polynomials."""
function resultant(left::SparsePolynomial, right::SparsePolynomial)
    _same_ring(left, right)
    left_coefficients = _univariate_coefficients(left)
    right_coefficients = _univariate_coefficients(right)
    (isempty(left_coefficients) || isempty(right_coefficients)) && return zero(Rational{BigInt})
    left_degree, right_degree = length(left_coefficients) - 1, length(right_coefficients) - 1
    matrix = zeros(Rational{BigInt}, left_degree + right_degree, left_degree + right_degree)
    for row in 1:right_degree
        matrix[row, row:row + left_degree] .= left_coefficients
    end
    for row in 1:left_degree
        matrix[right_degree + row, row:row + right_degree] .= right_coefficients
    end
    _determinant(matrix)
end

function _univariate_derivative(polynomial::SparsePolynomial)
    SparsePolynomial(polynomial.variables,
        Dict((exponent[1] - 1,) => coefficient * exponent[1]
             for (exponent, coefficient) in polynomial.terms if exponent[1] > 0))
end

"""
    discriminant(polynomial) -> Rational{BigInt}

Return the exact discriminant of a nonzero univariate rational polynomial.
The value is computed from the Sylvester resultant with its formal derivative,
so it is zero exactly when the polynomial has a repeated root over an algebraic
closure. Constants and linear polynomials have discriminant one.
"""
function discriminant(polynomial::SparsePolynomial)
    coefficients = _univariate_coefficients(polynomial)
    isempty(coefficients) && throw(ArgumentError("the zero polynomial has no discriminant"))
    degree = length(coefficients) - 1
    degree <= 1 && return one(Rational{BigInt})
    leading = first(coefficients)
    sign = isodd(div(degree * (degree - 1), 2)) ? -one(Rational{BigInt}) : one(Rational{BigInt})
    sign * resultant(polynomial, _univariate_derivative(polynomial)) / leading
end

function _univariate_degree(polynomial::SparsePolynomial)
    _univariate_coefficients(polynomial)
    iszero(polynomial) ? -1 : maximum(first(exponent) for exponent in keys(polynomial.terms))
end

function _univariate_divrem(dividend::SparsePolynomial, divisor::SparsePolynomial)
    _same_ring(dividend, divisor)
    _univariate_coefficients(dividend)
    _univariate_coefficients(divisor)
    iszero(divisor) && throw(ArgumentError("polynomial division by zero"))
    quotient = SparsePolynomial(dividend.variables, Dict())
    remainder = dividend
    divisor_degree = _univariate_degree(divisor)
    divisor_leading = divisor.terms[(divisor_degree,)]
    while !iszero(remainder) && _univariate_degree(remainder) >= divisor_degree
        remainder_degree = _univariate_degree(remainder)
        coefficient = remainder.terms[(remainder_degree,)] / divisor_leading
        term = SparsePolynomial(dividend.variables,
            Dict((remainder_degree - divisor_degree,) => coefficient))
        quotient += term
        remainder -= _multiply(divisor, term)
    end
    quotient, remainder
end

function _univariate_exact_quotient(dividend::SparsePolynomial, divisor::SparsePolynomial)
    quotient, remainder = _univariate_divrem(dividend, divisor)
    iszero(remainder) || throw(ArgumentError("polynomial division is not exact"))
    quotient
end

function _univariate_gcd(left::SparsePolynomial, right::SparsePolynomial)
    _same_ring(left, right)
    _univariate_coefficients(left)
    _univariate_coefficients(right)
    while !iszero(right)
        _, remainder = _univariate_divrem(left, right)
        left, right = right, remainder
    end
    iszero(left) ? left : _monic(left, :lex)
end

"""
    squarefree_decomposition(polynomial) -> Vector{NamedTuple}

Factor a nonzero univariate rational polynomial into monic square-free factors
and their positive multiplicities. The scalar leading coefficient is omitted:
the returned factors describe the root structure exactly over an algebraic
closure and can be used directly by exact factorization or solving backends.
"""
function squarefree_decomposition(polynomial::SparsePolynomial)
    _univariate_coefficients(polynomial)
    iszero(polynomial) && throw(ArgumentError("the zero polynomial has no square-free decomposition"))
    _univariate_degree(polynomial) <= 0 && return NamedTuple{(:factor, :multiplicity),Tuple{SparsePolynomial,Int}}[]
    derivative = _univariate_derivative(polynomial)
    repeated = _univariate_gcd(polynomial, derivative)
    remaining = _univariate_exact_quotient(polynomial, repeated)
    factors = NamedTuple{(:factor, :multiplicity),Tuple{SparsePolynomial,Int}}[]
    multiplicity = 1
    while _univariate_degree(remaining) > 0
        shared = _univariate_gcd(remaining, repeated)
        factor = _univariate_exact_quotient(remaining, shared)
        iszero(factor) || _univariate_degree(factor) == 0 ||
            push!(factors, (factor=_monic(factor, :lex), multiplicity=multiplicity))
        remaining = shared
        repeated = _univariate_exact_quotient(repeated, shared)
        multiplicity += 1
    end
    factors
end

function _positive_divisors(value::BigInt)
    value > 0 || return BigInt[]
    divisors = BigInt[]
    candidate = BigInt(1)
    while candidate * candidate <= value
        if value % candidate == 0
            push!(divisors, candidate)
            partner = div(value, candidate)
            partner == candidate || push!(divisors, partner)
        end
        candidate += 1
    end
    sort!(divisors)
end

function _evaluate_univariate(polynomial::SparsePolynomial, value::Rational{BigInt})
    _univariate_coefficients(polynomial)
    sum((coefficient * value^exponent[1] for (exponent, coefficient) in polynomial.terms);
        init=zero(Rational{BigInt}))
end

"""
    rational_roots(polynomial) -> Vector{NamedTuple}

Return every rational root of a nonzero univariate rational polynomial and its
exact multiplicity. Irreducible factors of degree greater than one are omitted;
this function never approximates algebraic or transcendental roots.
"""
function rational_roots(polynomial::SparsePolynomial)
    coefficients = _univariate_coefficients(polynomial)
    isempty(coefficients) && throw(ArgumentError("the zero polynomial has no roots"))
    _univariate_degree(polynomial) <= 0 && return NamedTuple{(:root, :multiplicity),Tuple{Rational{BigInt},Int}}[]
    denominator_scale = foldl(lcm, (denominator(coefficient) for coefficient in coefficients); init=BigInt(1))
    integer_coefficients = BigInt[numerator(coefficient) * div(denominator_scale, denominator(coefficient))
                                  for coefficient in coefficients]
    leading, constant = first(integer_coefficients), last(integer_coefficients)
    candidates = Set{Rational{BigInt}}()
    if iszero(constant)
        push!(candidates, zero(Rational{BigInt}))
    else
        for numerator_value in _positive_divisors(abs(constant)),
            denominator_value in _positive_divisors(abs(leading))
            candidate = numerator_value // denominator_value
            push!(candidates, candidate, -candidate)
        end
    end
    remaining = polynomial
    roots = NamedTuple{(:root, :multiplicity),Tuple{Rational{BigInt},Int}}[]
    for root in sort!(collect(candidates))
        _evaluate_univariate(remaining, root) == 0 || continue
        factor = SparsePolynomial(polynomial.variables, Dict((1,) => 1, (0,) => -root))
        multiplicity = 0
        while _evaluate_univariate(remaining, root) == 0
            remaining = _univariate_exact_quotient(remaining, factor)
            multiplicity += 1
        end
        push!(roots, (root=root, multiplicity=multiplicity))
    end
    roots
end

function _rational_root_residual(polynomial::SparsePolynomial,
                                 roots::AbstractVector{<:NamedTuple})
    residual = polynomial
    for entry in roots
        factor = SparsePolynomial(polynomial.variables, Dict((1,) => 1, (0,) => -entry.root))
        for _ in 1:entry.multiplicity
            residual = _univariate_exact_quotient(residual, factor)
        end
    end
    residual
end

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
    value = try
        Rational{BigInt}(SymbolicUtils.unwrap_const(expression))
    catch error
        error isa MethodError || rethrow()
        nothing
    end
    value === nothing || return value
    # A closed arithmetic expression is a coefficient too: OSR spells one half
    # `Power(2, -1)`, which is a term rather than a literal.
    closed = osr_number(expression)
    closed isa Union{Integer,Rational} || return nothing
    return Rational{BigInt}(closed)
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
    # The canonical OSR heads are uninterpreted symbols, so they are recognised
    # by name alongside the native operators they denote.
    name = _operation_name(operator)
    if operator === (+) || name === :Add
        return foldl(+, (_to_sparse_polynomial(operand, variables) for operand in operands);
                     init=SparsePolynomial(variables, Dict()))
    elseif operator === (*) || name === :Multiply
        return foldl(_multiply, (_to_sparse_polynomial(operand, variables) for operand in operands);
                     init=_constant_polynomial(variables, 1))
    elseif (operator === (-) || name === :Subtract) && length(operands) == 2
        return _to_sparse_polynomial(operands[1], variables) +
               _multiply(_constant_polynomial(variables, -1),
                         _to_sparse_polynomial(operands[2], variables))
    elseif (operator === (^) || name === :Power) && length(operands) == 2
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
export to_sparse_polynomial, to_symbolic_polynomial, resultant, discriminant, squarefree_decomposition, rational_roots
