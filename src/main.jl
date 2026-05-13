function @main(ARGS)
    options = parse_options(ARGS)
    return main_loop(options)
end

function main_loop(options)
    (; check, diff, inplace, lines, output, stdin_filename, verbose,
     version, files) = options

    # Ignore all other command line arguments if --version is present.
    if version
        version = pkgversion(@__MODULE__)
        println("gossamer version $(version), julia version $(VERSION)")
        return 0
    end

    inplace && !isnothing(output) && return(fatal("options `--inplace` and `--output` are mutually exclusive"))

    # Investigate input files.
    filenames = String[]
    dir_found = false
    use_stdin_input = isempty(files)
    for file in files
        if file == "-"
            use_stdin_input = true
        elseif isfile(file)
            push!(filenames, file)
        elseif isdir(file)
            dir_found = true
            add_jl_files_recursively!(filenames, file)
        end
    end

    use_stdin_input && inplace && return fatal("option `--inplace` can not be used together with stdin input")

    number_of_files = length(filenames) + use_stdin_input

    if number_of_files > 1
        inplace || check || return fatal("option `--inplace` or `--check` required with multiple input files")
        isnothing(output) || return fatal("option `--output` can not be used with multiple input files")
    end

    success = true
    index = 1

    for filename in filenames
        success &= format_file(filename, read(filename, String), index,
                               number_of_files, options)
        index += 1
    end

    if use_stdin_input
        name = isnothing(stdin_filename) ? "<stdin>" : stdin_filename
        success &= format_file(name, read(stdin, String), index,
                               number_of_files, options)
    end

    return success ? 0 : 1
end

function fatal(message)
    printstyled(stderr, "ERROR: ", color = :red)
    println(message)
    return 1
end

function format_file(filename, content, index, number_of_files, options)
    (; check, diff, inplace, lines, output, verbose) = options

    if verbose
        message = string("[", lpad(index, length(string(number_of_files))),
                         "/", number_of_files, "] Checking `$(filename)` ")
        printstyled(rpad(message, 78, "."), " ", color = :blue)
    end

    node = nothing
    try
        node = parse_string(filename, content)
    catch e
        if e isa JuliaSyntax.ParseError
            showerror(stderr, e)
            println(stderr)
        else
            showerror(stderr, e)
            println(stderr)
        end
    end

    if isnothing(node)
        verbose && printstyled("✖\n", color = :red)
        return false
    end

    format_node!(node)
    success = true
    if check || verbose
        success = content == write_node(node)
    end

    if verbose
        success || printstyled("✖\n", color = :red)
        success && printstyled("✔\n", color = :green)
    end

    if !check
        if inplace
            success || write_node(filename, output)
        elseif isnothing(output)
            write_node(stdout, node)
        else
            write_node(output, node)
        end
    end

    if diff
        show_diff(filename, content, node)
    end

    return success | !check
end

function show_diff(filename, content, node)
    mktempdir() do tmpdir
        a_dir = mkdir(joinpath(tmpdir, "a"))
        b_dir = mkdir(joinpath(tmpdir, "b"))
        name = basename(filename)
        a_file = joinpath(a_dir, name)
        b_file = joinpath(b_dir, name)
        write(a_file, content)
        write_node(b_file, node)
        rel_a_file = relpath(a_file, tmpdir)
        rel_b_file = relpath(b_file, tmpdir)
        cmd = `git -C $tmpdir --no-pager diff --color=auto --no-index --no-prefix $rel_a_file $rel_b_file`
        run(pipeline(ignorestatus(cmd), stdout = stderr))
    end
end

function add_jl_files_recursively!(filenames, dir)
    for (root, _, files) in walkdir(dir)
        for file in files
            endswith(file, ".jl") && push!(filenames, joinpath(root, file))
        end
    end
    return
end
