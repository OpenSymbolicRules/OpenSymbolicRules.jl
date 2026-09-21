using SymbolicUtils

"""
    OperationResult

What a high-level operation reached, and how that reading should be taken.

An expression on its own cannot say whether it was proved, assumed, or simply
not carried out — and an unknown result read as a proved equality is the one
mistake this package is built to avoid. An `OperationResult` says which it is.

The readings are:

| status | meaning |
| --- | --- |
| `:proved` | a closed form the rules established outright |
| `:conditional` | a closed form, valid where the recorded assumptions hold |
| `:unevaluated` | the operation is still standing in the value |
| `:inapplicable` | the operation does not apply to this argument |
| `:divergent` | the operation has no finite value here |

See [`status`](@ref), [`value`](@ref), and [`assumptions`](@ref).
"""
struct OperationResult <: CASResult
    operation::Symbol
    status::Symbol
    value::Any
    assumptions::Vector{Any}
    function OperationResult(operation::Symbol, status::Symbol, value,
                             assumptions=Any[])
        status in _OPERATION_STATUSES ||
            throw(ArgumentError("unknown operation status: $(status)"))
        new(operation, status, value, collect(Any, assumptions))
    end
end

const _OPERATION_STATUSES =
    (:proved, :conditional, :unevaluated, :inapplicable, :divergent)

"""
    status(result)

Return how a result should be read: one of `:proved`, `:conditional`,
`:unevaluated`, `:inapplicable`, or `:divergent`.
"""
status(result::OperationResult) = result.status

"""
    value(result)

Return the expression a result reached.  For an `:unevaluated` result that is
the operation still standing, not a closed form.
"""
value(result::OperationResult) = result.value

"""
    assumptions(result)

Return the facts a `:conditional` result was reached under, and nothing for the
other readings.
"""
assumptions(result::OperationResult) = result.assumptions

function Base.show(io::IO, result::OperationResult)
    print(io, result.operation, ": ", result.status, "\n  ", result.value)
    isempty(result.assumptions) && return
    print(io, "\n  assuming ", join(string.(result.assumptions), ", "))
end

"""
    _active_assumptions()

Return the hypotheses in force, which is what makes a result conditional rather
than proved.
"""
function _active_assumptions()
    context = get(task_local_storage(), :osr_assumptions, nothing)
    context === nothing && return Any[]
    return collect(Any, context)
end

"""
    _operation_result(operation, expression, unevaluated)

Read `expression` as the result of `operation`, which `unevaluated` says is
still standing.
"""
function _operation_result(operation::Symbol, expression, unevaluated::Bool)
    unevaluated && return OperationResult(operation, :unevaluated, expression)
    facts = _active_assumptions()
    isempty(facts) && return OperationResult(operation, :proved, expression)
    return OperationResult(operation, :conditional, expression, facts)
end

export OperationResult, status, value, assumptions
