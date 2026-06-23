precompile(main, (Vector{String},))
precompile(Tuple{typeof(Base.showerror), Base.TTY, JuliaSyntax.ParseError})

precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:bold, :italic, :underline, :blink, :reverse, :hidden, :color), Tuple{Bool, Bool, Bool, Bool, Bool, Bool, Symbol}}, typeof(Base.printstyled), Base.TTY, String, Vararg{String}})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:bold, :italic, :underline, :blink, :reverse, :hidden), NTuple{6, Bool}}, typeof(Base.with_output_color), Function, Symbol, Base.TTY, String, Vararg{String}})
