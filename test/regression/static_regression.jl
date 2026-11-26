using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Gossamer: locate_input_files, parse_string, format_node!, write_node,
                show_diff
import JuliaSyntax

include("ignore.jl")

function main(args)
    if length(args) < 1
        println(stderr, "Usage: julia staticregression.jl [--summary] paths...")
        return 1
    end

    static_gossamer_path = abspath(@__DIR__, "../../staticcompiler/gossamer")
    if !isfile(static_gossamer_path)
        println(stderr, "No static binary found at $(static_gossamer_path)")
        return 1
    end
    static_gossamer = `$(static_gossamer_path)`

    files = args
    summary = "--summary" in files
    filter!(!=("--summary"), files)
    filenames, use_stdin_input = locate_input_files(files)
    use_stdin_input && return Gossamer.fatal("stdin input not supported for static regression")
    for (index, filename) in enumerate(filenames)
        file_causes_stack_overflow(filename) && continue
        check_file_for_regressions(static_gossamer, filename, index,
                                   length(filenames), summary)
    end
    println(" "^80, "\r")
end

function check_file_for_regressions(static_gossamer, filename, index,
                                    number_of_files, summary)
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

    if isnothing(node)
        return
    end

    format_node!(node)
    out = write_node(node)
    ref_out = read(`$(static_gossamer) $filename`, String)

    if out == ref_out
        printstyled("✔\r", color = :green)
    else
        printstyled("✖\n", color = :red)
        summary || show_diff(filename, ref_out, node)
    end
end

main(ARGS)
