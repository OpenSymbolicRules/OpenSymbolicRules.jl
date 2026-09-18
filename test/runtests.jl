using TestItemRunner
@run_package_tests
include("test_macro.jl")
include("test_predicates.jl")
include("test_simplify.jl")
include("test_manifests.jl")
ecosystem_root = normpath(joinpath(@__DIR__, "..", ".."))
if isfile(joinpath(ecosystem_root, "Calculus", "rules", "meta.json"))
    include("test_real_profiles.jl")
else
    @info "Skipping sibling-repository profile tests outside the ecosystem checkout"
end
include("test_named_rules.jl")
include("test_ac_matching.jl")
include("test_constraints.jl")
include("test_binders.jl")
include("test_dispatch.jl")
include("test_equality_theory.jl")
include("test_groebner.jl")
include("test_exact_radicals.jl")
include("test_linear_theory.jl")
include("test_numeric_smt.jl")
include("test_polynomial_bridge.jl")
include("test_rational_assumptions.jl")
include("test_sat.jl")
include("test_operations.jl")
include("test_wildcards.jl")
include("test_prove.jl")
include("test_piecewise.jl")
include("test_context.jl")
test_project = read(joinpath(@__DIR__, "Project.toml"), String)
if occursin(r"(?m)^OpenMath\s*=", test_project)
    include("test_openmath_ext.jl")
else
    @info "Skipping opt-in OpenMath extension tests"
end
