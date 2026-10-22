using Test
using Gossamer: format_string

@testset "Empty file" begin
    @test format_string("") == ""
end

@testset "Formatting rules" begin
    include("format.jl")
end

@testset "Newline conventions" begin
    include("newline_conventions.jl")
end
