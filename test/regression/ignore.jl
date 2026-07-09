# These files are known to cause stack overflow in JuliaSyntax.
function file_causes_stack_overflow(filename)
    contains(filename, r"JuliaSyntax/(\w+/)?src/tokenize_utils.jl") && return true
    contains(filename, r"Tokenize/(\w+/)?src/utilities.jl") && return true
    return false
end
