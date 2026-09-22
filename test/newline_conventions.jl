@testset "Newline conventions" begin
    for filename in readdir(joinpath(@__DIR__, "data"), join = true)
        endswith(filename, ".jl") || continue
        @testset "$(first(splitext(basename(filename))))" begin
            original = read(filename, String)
            # We don't know the newline convention of original as this
            # may depend on the platform, but we can always normalize
            # it.
            in_lf = replace(original, "\r\n" => "\n")
            in_crlf = replace(in_lf, "\n" => "\r\n")
            # Format the entire files with both newline conventions.
            out_lf = format_string(in_lf)
            out_crlf = format_string(in_crlf)
            # Check that both outputs have consistent and expected
            # newlines.
            @test out_lf == replace(replace(out_lf, "\n" => "\r\n"), "\r\n" => "\n")
            @test out_crlf == replace(replace(out_crlf, "\r\n" => "\n"), "\n" => "\r\n")
            # Test that the formattings match.
            @test out_lf == replace(out_crlf, "\r\n" => "\n")
        end
    end
end
