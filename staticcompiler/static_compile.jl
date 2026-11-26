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

# This should presumably somehow help when removing the last override
# in override_gossamer.jl, but does not seem to have any effect.
add_dispatch_candidates!(Gossamer.Node, Gossamer.IndentState)

compile_executable(Gossamer.main, (Vector{String},), @__DIR__, "gossamer")
