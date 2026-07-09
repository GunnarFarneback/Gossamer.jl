using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Gossamer: locate_input_files, parse_string, format_node!, write_node,
                show_diff
import JuliaSyntax
import Profile

include("ignore.jl")

function main(args)
    if length(args) < 1
        println(stderr, "Usage: julia profile.jl paths...")
        return 1
    end

    filenames, use_stdin_input = locate_input_files(args)
    use_stdin_input && return Gossamer.fatal("stdin input not supported for idempotence checking")
    for (index, filename) in enumerate(filenames)
        file_causes_stack_overflow(filename) && continue
        run_profile(filename, index, length(filenames))
    end
    println(" "^80, "\r")
    Profile.print(format = :flat)
end

function run_profile(filename, index, number_of_files)
    n = length(string(number_of_files))
    file_string = rpad(filename * " ", 73 - 2 * n, ".")
    t = 73 - 2 * n
    if length(file_string) > t
        file_string = string("...", chop(file_string,
                                         head = length(file_string) - t + 2))
    end
    message = string("[", lpad(index, n), "/", number_of_files, "] ",
                     file_string)
    printstyled(message, " ", color = :blue)
    content = read(filename, String)

    node = nothing
    try
        node = parse_string(content)
    catch e
        if !(e isa JuliaSyntax.ParseError)
            printstyled("?\n", color = :yellow)
            showerror(stderr, e)
            println(stderr)
        else
            printstyled("?\r", color = :yellow)
        end
    end

    isnothing(node) && return

    Profile.@profile node = parse_string(content)
    Profile.@profile format_node!(node)
    Profile.@profile write_node(node)
    print("\r")
end

main(ARGS)
