# Changes:
# * Replace `stderr` with `StaticRuntime.STDERR`. To be able to do
#   this is the whole purpose of having this function.
@device_override Gossamer._stderr() = STDERR

# Changes:
# * Comment out the last call. This disables all indentation
#   functionality but is necessary until bugs have been tracked down.
#   With the last call enabled, result is the runtime error
#   ```
#   MethodError: no method matching `Gossamer.IndentState` with the given argument types.
#   This may be due to a type that the program was not found to make when compiling: `add_dispatch_candidates!(T)` adds one.
#   ```
@device_override function Gossamer.format_node!(node::Gossamer.Node)
    # Catch corner case of empty file.
    isempty(node.children) && return

    Gossamer.move_newlines!(node)
    Gossamer.format_spaces!(node)
    Gossamer.format_indent!(node)
end

# Changes:
# * Only show parse errors from JuliaSyntax.
@device_override function Gossamer._showerror(e)
    if e isa JuliaSyntax.ParseError
        showerror(STDERR, e)
        println(STDERR)
    end
end
