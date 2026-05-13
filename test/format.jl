using Gossamer: format_string

function print_formatting_failure(filename, formatted, expected)
    formatted == expected && return
    printstyled(stderr, "In ", filename, ":\n", color = :yellow)
    printstyled(stderr, "Formatted:\n", color = :blue)
    println(stderr, formatted)
    printstyled(stderr, "Expected:\n", color = :blue)
    println(stderr, expected)
end

# Tests defined by the files in test/data.
#
# The semantics of those files are
# * Cases are split by one or more consecutive lines starting with `##`.
#   * There may be comment text on those lines.
# * If a case contains a line with a single `#`:
#   * The part before should be formatted into the part after.
#   * The part after should be formatted into itself.
# * Otherwise the whole case should be formatted into itself.
for filename in readdir(joinpath(@__DIR__, "data"), join = true)
    endswith(filename, ".jl") || continue
    @testset "$(first(splitext(basename(filename))))" begin
        data = read(filename, String)
        for test in eachsplit(data, r"##\N*\n")
            isempty(test) && continue
            parts = split(test, "#\n")
            @assert 1 <= length(parts) <= 2
            if length(parts) == 1
                # The code should not change from formatting.
                formatted = format_string(parts[1])
                print_formatting_failure(filename, formatted, parts[1])
                @test formatted == parts[1]
            else
                # The first part should format into the second part.
                # The second part should format into itself.
                formatted1 = format_string(parts[1])
                formatted2 = format_string(parts[2])
                print_formatting_failure(filename, formatted1, parts[2])
                @test formatted1 == parts[2]
                print_formatting_failure(filename, formatted2, parts[2])
                @test formatted2 == parts[2]
            end
        end
    end
end
