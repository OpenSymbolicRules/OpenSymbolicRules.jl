using OpenSymbolicRules
using Documenter

DocMeta.setdocmeta!(OpenSymbolicRules, :DocTestSetup, :(using OpenSymbolicRules); recursive = true)

# Add titles of sections and overrides page titles
const titles = Dict(
    "10-tutorials" => "Tutorials", # example folder title
    "91-developer.md" => "Developer docs",
)

function recursively_list_pages(folder; path_prefix="")
    pages_list = Any[]
    for file in readdir(folder)
        if file == "index.md"
            # We add index.md separately to make sure it is the first in the list
            continue
        end
        # this is the relative path according to our prefix, not @__DIR__, i.e., relative to `src`
        relpath = joinpath(path_prefix, file)
        # full path of the file
        fullpath = joinpath(folder, relpath)

        if isdir(fullpath)
            # If this is a folder, enter the recursion case
            subsection = recursively_list_pages(fullpath; path_prefix=relpath)

            # Ignore empty folders
            if length(subsection) > 0
                title = if haskey(titles, relpath)
                titles[relpath]
                else
                @error "Bad usage: '$relpath' does not have a title set. Fix in 'docs/make.jl'"
                relpath
                end
                push!(pages_list, title => subsection)
            end

            continue
        end

        if splitext(file)[2] != ".md" # non .md files are ignored
            continue
        elseif haskey(titles, relpath) # case 'title => path'
            push!(pages_list, titles[relpath] => relpath)
        else # case 'title'
            push!(pages_list, relpath)
        end
    end

    return pages_list
end

function list_pages()
    root_dir = joinpath(@__DIR__, "src")
    pages_list = recursively_list_pages(root_dir)

    return ["index.md"; pages_list]
end

makedocs(;
    modules = [OpenSymbolicRules],
    authors = "Sébastien Celles",
    repo = Remotes.GitHub("OpenSymbolicRules", "OpenSymbolicRules.jl"),
    sitename = "OpenSymbolicRules.jl",
    format = Documenter.HTML(; canonical = "https://OpenSymbolicRules.github.io/OpenSymbolicRules.jl", edit_link = "main", repolink = "https://github.com/OpenSymbolicRules/OpenSymbolicRules.jl", size_threshold_warn = 150 * 2^10),
    pages = list_pages(),
)

if get(ENV, "CI", "false") == "true"
    deploydocs(; repo = "github.com/OpenSymbolicRules/OpenSymbolicRules.jl", devbranch = "main")
end

# Generate llms.txt and llms-full.txt
open(joinpath(@__DIR__, "build", "llms.txt"), "w") do io
    println(io, "# OpenSymbolicRules.jl")
    println(io, "> A universal, zero-overhead client for Open Symbolic Rules.")
    println(io, "\nThis package reads OSR JSON files at compile-time and translates them into native SymbolicUtils.jl rewrite rules.")
end

open(joinpath(@__DIR__, "build", "llms-full.txt"), "w") do io
    println(io, "# OpenSymbolicRules.jl - Full Documentation")
    println(io, read(joinpath(@__DIR__, "src", "index.md"), String))
end
