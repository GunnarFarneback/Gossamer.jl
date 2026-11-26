import Gossamer
using StaticRuntime

if VERSION < v"1.14-" || VERSION >= v"1.15-"
    error("Only Julia 1.14 is supported, not $VERSION")
end

# All these overrides go deep into the internals of respective
# dependencies and could break on any new version of the
# dependency. Therefore Project.toml locks the compat down to a single
# version.
include("overrides_base.jl")
include("overrides_juliasyntax.jl")
include("overrides_gossamer.jl")

# Convince StaticRuntime that it's fine to print color. (This is not
# always correct, such as when piping output to a file.)
Base.get(::StaticIO, key::Symbol, default) = (key == :color) ? true : default

compile_executable(Gossamer.main, (Vector{String},), @__DIR__, "gossamer",
                   libraries = :bundle, small = true)
