struct _PolynomialState
    problem::UnivariatePolynomialProblem
    backend::CASBackend
    options::SolveOptions
end

CommonSolve.init(problem::UnivariatePolynomialProblem,
                 backend::CASBackend=BuiltinBackend(); options::SolveOptions=SolveOptions()) =
    _PolynomialState(problem, backend, options)

function CommonSolve.solve!(state::_PolynomialState)
    state.backend isa BuiltinBackend || return UnknownResult(:unsupported_backend, state.backend)
    state.options.require_certificate && return UnknownResult(:certificate_unavailable, state.backend)
    roots = rational_roots(state.problem.polynomial)
    residual = _rational_root_residual(state.problem.polynomial, roots)
    PolynomialRootsResult(roots, residual, _univariate_degree(residual) <= 0, state.backend)
end
