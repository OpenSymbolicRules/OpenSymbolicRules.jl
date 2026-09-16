using SymbolicUtils

export Equation

struct Equation
    lhs
    rhs
end

Base.:~(a::SymbolicUtils.BasicSymbolic, b::SymbolicUtils.BasicSymbolic) = Equation(a, b)
Base.:~(a::SymbolicUtils.BasicSymbolic, b::Any) = Equation(a, b)
Base.:~(a::Any, b::SymbolicUtils.BasicSymbolic) = Equation(a, b)

Base.show(io::IO, eq::Equation) = print(io, eq.lhs, " ~ ", eq.rhs)
Base.isequal(a::Equation, b::Equation) = isequal(a.lhs, b.lhs) && isequal(a.rhs, b.rhs)
Base.:(==)(a::Equation, b::Equation) = isequal(a, b)
