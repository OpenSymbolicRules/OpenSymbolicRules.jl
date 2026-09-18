"""Bounded trial-division limit for exact square-root normalization."""
const _PERFECT_SQUARE_TRIAL_LIMIT = 10_000

function _primes_up_to(limit::Int)
    limit < 2 && return Int[]
    sieve = trues(limit)
    sieve[1] = false
    for candidate in 2:isqrt(limit)
        sieve[candidate] || continue
        sieve[candidate * candidate:candidate:limit] .= false
    end
    findall(sieve)
end

const _PERFECT_SQUARE_TRIAL_PRIMES = _primes_up_to(_PERFECT_SQUARE_TRIAL_LIMIT)

function _split_perfect_square(value::Integer)
    value >= 0 || throw(ArgumentError("perfect-square extraction requires a nonnegative integer"))
    scale, remainder = one(value), value
    for prime in _PERFECT_SQUARE_TRIAL_PRIMES
        prime_squared = prime * prime
        prime_squared > remainder && break
        while iszero(rem(remainder, prime_squared))
            remainder = div(remainder, prime_squared)
            scale *= prime
        end
    end
    root = isqrt(remainder)
    if root * root == remainder
        scale *= root
        remainder = one(value)
    end
    scale, remainder
end

"""
    normalize_sqrt(value)

Construct an exact OSR square-root expression for a numeric integer or rational
literal. Perfect squares become exact numbers; otherwise a bounded perfect
square factor is extracted and the remaining `Sqrt` head retains the OpenMath
`arith1#root` semantics. Negative and nonnumeric values remain unevaluated.
"""
function normalize_sqrt(value::Union{Integer,Rational})
    value < 0 && return Sqrt(value)
    iszero(value) && return zero(value)
    isone(value) && return one(value)
    numerator_value, denominator_value = numerator(value), denominator(value)
    scale, remainder = _split_perfect_square(numerator_value * denominator_value)
    coefficient = scale // denominator_value
    radicand = remainder
    isone(radicand) && return coefficient
    radical = Sqrt(radicand)
    isone(coefficient) ? radical : coefficient * radical
end

normalize_sqrt(value) = Sqrt(value)

export normalize_sqrt
