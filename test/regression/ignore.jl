# These files are known to cause stack overflow in JuliaSyntax.
function file_causes_stack_overflow(filename)
    contains(filename, r"JuliaSyntax/(\w+/)?src/tokenize_utils.jl") && return true
    contains(filename, r"Tokenize/(\w+/)?src/utilities.jl") && return true
    # Parse error rather than stack overflow.
    contains(filename, "julia/test/syntax.jl") && return true
    return false
end
