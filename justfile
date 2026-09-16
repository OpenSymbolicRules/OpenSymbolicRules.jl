# Justfile for common entry points

test:
	julia --project -e 'using Pkg; Pkg.test()'

doc:
	julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); include("docs/make.jl")'

format:
	julia -e 'using JuliaFormatter; format(".")'
