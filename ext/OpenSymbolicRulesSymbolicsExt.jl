module OpenSymbolicRulesSymbolicsExt

using OpenSymbolicRules
using Symbolics
using SymbolicUtils
using SymbolicUtils: operation, arguments, iscall
using SymbolicUtils.Rewriters: Postwalk

function OpenSymbolicRules.to_osr(expr)
    Postwalk(x -> begin
        if iscall(x)
            op = operation(x)
            if op isa Symbolics.Differential
                var = op.x
                # Symbolics.jl represents diff as Differential(x)(expr)
                # OSR represents it as Derivative(Lambda(x, expr))
                return term(OpenSymbolicRules.Derivative, term(OpenSymbolicRules.Lambda, var, arguments(x)[1]))
            end
        end
        return x
    end)(expr)
end

function OpenSymbolicRules.to_symbolics(expr)
    Postwalk(x -> begin
        if iscall(x)
            op = operation(x)
            if isequal(op, OpenSymbolicRules.Derivative)
                lambda_term = arguments(x)[1]
                if iscall(lambda_term) && isequal(operation(lambda_term), OpenSymbolicRules.Lambda)
                    var_arg = arguments(lambda_term)[1]
                    expr_arg = arguments(lambda_term)[2]
                    return term(Symbolics.Differential(var_arg), expr_arg)
                end
            end
        end
        return x
    end)(expr)
end

end
