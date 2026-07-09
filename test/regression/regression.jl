using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Gossamer: locate_input_files, parse_string, format_node!, write_node,
                show_diff
import JuliaSyntax
using ReferenceRevision: open_process

include("ignore.jl")

function main(args)
    if length(args) < 2
        println(stderr, "Usage: julia regression.jl revision [--summary] paths...")
        return 1
    end

    revision = first(args)
    reference = open_process(rev = revision, subdir = ".", instantiate = true,
                             use = [:Gossamer, :JuliaSyntax])

    files = args[2:end]
    summary = "--summary" in files
    filter!(!=("--summary"), files)
    filenames, use_stdin_input = locate_input_files(files)
    use_stdin_input && return Gossamer.fatal("stdin input not supported for regression")
    for (index, filename) in enumerate(filenames)
        file_causes_stack_overflow(filename) && continue
        check_file_for_regressions(reference.Gossamer, filename, index,
                                   length(filenames), summary)
    end
    println(" "^80, "\r")
end

function check_file_for_regressions(reference, filename, index, number_of_files,
                                    summary)
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
    ref_out = reference.format_string(content)

    if out == ref_out
        printstyled("✔\r", color = :green)
    else
        printstyled("✖\n", color = :red)
        summary || show_diff(filename, ref_out, node)
    end
end

main(ARGS)
