using Gossamer: format_string

# Define a custom AbstractTestSet to suppress useless backtraces on
# failures. This just wraps a DefaultTestSet and overrides the
# printing of failures.
#
# Unfortunately this implementation goes into internals of the Test
# stdlib, so might break with new minor versions of Julia.
#
# (Actually nothing at all is declared public for the AbstractTestSet
# interface, which itself is just a code comment. But the print_result
# kwarg for record is probably the most likely part to break.)
struct CustomTestSet <: Test.AbstractTestSet
    ts::Test.DefaultTestSet
    CustomTestSet(ts::Test.DefaultTestSet) = new(ts)
end

function CustomTestSet(args...; kwargs...)
    CustomTestSet(Test.DefaultTestSet(args...; kwargs...))
end

Test.record(cts::CustomTestSet, t) = Test.record(cts.ts, t)
function Test.record(cts::CustomTestSet, t::Test.Fail)
    Test.record(cts.ts, t; print_result = false)
end

Test.finish(cts::CustomTestSet) = Test.finish(cts.ts)


function print_formatting_failure(filename, line_number,
                                  original, formatted, expected)
    formatted == expected && return
    printstyled(stderr, "On line $(line_number) of $(filename):\n",
                color = :yellow)
    printstyled(stderr, "Original:\n", color = :blue)
    println(stderr, original)
    printstyled(stderr, "Formatted:\n", color = :blue)
    println(stderr, formatted)
    printstyled(stderr, "Expected:\n", color = :blue)
    println(stderr, expected)
end

function split_tests(filename)
    tests = Tuple{Int, String}[]
    start_line = 0
    text = String[]
    for (line_number, line) in enumerate(vcat(readlines(filename), "##"))
        if startswith(line, "##") && !startswith(line, "###")
            if !isempty(text)
                push!(tests, (start_line, join(text, "\n")))
                start_line = 0
                empty!(text)
            end
        else
            if start_line == 0
                start_line = line_number
            end
            push!(text, line)
        end
    end

    return tests
end

# Tests defined by the files in test/data.
#
# The semantics of those files are
# * Cases are split by one or more consecutive lines starting with `##`
#   but not starting with `###`.
#   * There may be comment text on those lines.
# * If a case contains a line with a single `#`:
#   * The part before should be formatted into the part after.
#   * The part after should be formatted into itself.
# * Otherwise the whole case should be formatted into itself.
for filename in readdir(joinpath(@__DIR__, "data"), join = true)
    endswith(filename, ".jl") || continue
    @testset CustomTestSet "$(first(splitext(basename(filename))))" begin
        for (line_number, test) in split_tests(filename)
            @testset "Line $line_number" begin
                isempty(test) && continue
                parts = split(test, "\n#\n")
                @assert 1 <= length(parts) <= 2
                if length(parts) == 1
                    # The code should not change from formatting.
                    formatted = format_string(parts[1])
                    print_formatting_failure(filename, line_number,
                                             parts[1],
                                             formatted, parts[1])
                    @test formatted == parts[1]
                else
                    # The first part should format into the second part.
                    # The second part should format into itself.
                    formatted1 = format_string(parts[1])
                    formatted2 = format_string(parts[2])
                    print_formatting_failure(filename, line_number,
                                             parts[1],
                                             formatted1, parts[2])
                    print_formatting_failure(filename, line_number,
                                             parts[2],
                                             formatted2, parts[2])
                    @test formatted1 == parts[2] && formatted2 == parts[2]
                end
            end
        end
    end
end
