"""
    OSRInference

One multi-premise inference declared by an Open Symbolic Rules inference
manifest.  Values remain JSON-compatible; applying an inference is the
responsibility of the host proof engine.
"""
struct OSRInference
    id::Int
    premises::Vector{Any}
    constraints::Vector{Any}
    conclusion::Any
    description::Union{Nothing,String}
end

function _rules_directory(root::AbstractString)
    root_path = abspath(root)
    if isfile(joinpath(root_path, "meta.json"))
        return root_path
    end

    rules_path = joinpath(root_path, "rules")
    isfile(joinpath(rules_path, "meta.json")) && return rules_path

    throw(ArgumentError("No OSR rules manifest found below $(root)"))
end

function _profile_paths(root::AbstractString, field::String, profile::Symbol)
    rules_path = _rules_directory(root)
    meta = JSON.parsefile(joinpath(rules_path, "meta.json"))
    profiles = get(meta, field, nothing)
    profiles isa AbstractDict || throw(ArgumentError("OSR manifest has no $(field) declarations"))
    profile_data = get(profiles, String(profile), nothing)
    profile_data isa AbstractDict || throw(ArgumentError("Unknown OSR profile: $(profile)"))
    load_order = get(profile_data, "load_order", nothing)
    load_order isa AbstractVector || throw(ArgumentError("OSR profile $(profile) has no load_order"))

    paths = String[]
    for relative_path in load_order
        relative_path isa String || throw(ArgumentError("OSR manifest paths must be strings"))
        rule_relative = normpath(joinpath(rules_path, relative_path))
        repository_relative = normpath(joinpath(dirname(rules_path), relative_path))
        if isfile(rule_relative)
            push!(paths, rule_relative)
        elseif isfile(repository_relative)
            push!(paths, repository_relative)
        else
            throw(ArgumentError("OSR manifest file not found: $(relative_path)"))
        end
    end
    return paths
end

"""
    rule_paths(root; profile=nothing)

Return the ordered rewrite manifests declared by an OSR repository or its
`rules` directory.  With `profile`, return the named rewrite profile.
"""
function rule_paths(root::AbstractString; profile::Union{Nothing,Symbol}=nothing)
    profile === nothing || return _profile_paths(root, "profiles", profile)

    rules_path = _rules_directory(root)
    meta = JSON.parsefile(joinpath(rules_path, "meta.json"))
    load_order = get(meta, "load_order", nothing)
    load_order isa AbstractVector || throw(ArgumentError("OSR manifest has no load_order"))
    return [normpath(joinpath(rules_path, path)) for path in load_order]
end

"""
    load_inference_profile(root, profile)

Load the structured multi-premise inferences declared by a named OSR inference
profile.  This function does not execute inferences.
"""
function load_inference_profile(root::AbstractString, profile::Symbol)
    inferences = OSRInference[]
    for path in _profile_paths(root, "inference_profiles", profile)
        document = JSON.parsefile(path)
        for entry in get(document, "inferences", Any[])
            push!(inferences, OSRInference(
                entry["id"],
                Vector{Any}(entry["premises"]),
                Vector{Any}(get(entry, "constraints", Any[])),
                entry["conclusion"],
                get(entry, "description", nothing),
            ))
        end
    end
    return inferences
end
