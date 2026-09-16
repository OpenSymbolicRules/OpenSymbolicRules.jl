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
                return term(OpenSymbolicRules.Derivative, arguments(x)[1], var)
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
                expr_arg = arguments(x)[1]
                var_arg = arguments(x)[2]
                return term(Symbolics.Differential(var_arg), expr_arg)
            end
        end
        return x
    end)(expr)
end

end
