if VERSION < v"1.14-" || VERSION >= v"1.15-"
    error("Only Julia 1.14 is supported, not $VERSION")
end

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

import Gossamer
import JuliaSyntax
using StaticRuntime: compile_executable, @device_override, StaticIO, STDERR

# Changes:
# * Only show parse errors from JuliaSyntax.
@device_override function Gossamer._showerror(e)
    if e isa JuliaSyntax.ParseError
        showerror(stderr, e)
        println(stderr)
    end
end

# Convince StaticRuntime that it's fine to print color. (This is not
# always correct, such as when piping output to a file.)
Base.get(::StaticIO, key::Symbol, default) = (key == :color) ? true : default

compile_executable(Gossamer.main, (Vector{String},), @__DIR__, "gossamer",
                   libraries = :bundle, small = true)
