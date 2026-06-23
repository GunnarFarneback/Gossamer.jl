using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Gossamer: locate_input_files, parse_string, format_node!, write_node,
                show_diff
import JuliaSyntax

function main(args)
    if length(args) < 1
        println(stderr, "Usage: julia idempotence.jl paths...")
        return 1
    end

    filenames, use_stdin_input = locate_input_files(args)
    use_stdin_input && return Gossamer.fatal("stdin input not supported for idempotence checking")
    for (index, filename) in enumerate(filenames)
        check_file_for_idempotency(filename, index, length(filenames))
    end
    println(" "^80, "\r")
end

function check_file_for_idempotency(filename, index, number_of_files)
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
        printstyled("?\n", color = :yellow)
    end

    isnothing(node) && return

    format_node!(node)
    out1 = write_node(node)
    format_node!(node)
    out2 = write_node(node)

    if out1 == out2
        printstyled("✔\r", color = :green)
    else
        printstyled("✖\n", color = :red)
        show_diff(filename, out1, node)
    end
end

main(ARGS)
