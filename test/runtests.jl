using TestItemRunner
@run_package_tests
include("test_macro.jl")
include("test_predicates.jl")
include("test_simplify.jl")
include("test_manifests.jl")
include("test_named_rules.jl")
include("test_ac_matching.jl")
include("test_constraints.jl")
