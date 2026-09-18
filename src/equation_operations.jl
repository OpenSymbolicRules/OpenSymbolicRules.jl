"""
    solve(equation, variable; backend=BuiltinBackend(), options=SolveOptions())

Solve the exact univariate rational-polynomial fragment of an `Equation`.
The returned `PolynomialRootsResult` contains every rational root, its
multiplicity, the unresolved residual factor, and whether the result is
complete. Non-polynomial equations are rejected rather than approximated.
"""
function CommonSolve.solve(equation::Equation, variable::SymbolicUtils.BasicSymbolic;
                           backend::CASBackend=BuiltinBackend(),
                           options::SolveOptions=SolveOptions())
    name = try
        SymbolicUtils.getname(variable)
    catch error
        error isa ArgumentError || rethrow()
        throw(ArgumentError("the equation variable must be a named symbolic variable"))
    end
    polynomial = to_sparse_polynomial(equation.lhs - equation.rhs, [name])
    CommonSolve.solve(UnivariatePolynomialProblem(polynomial), backend; options)
end
