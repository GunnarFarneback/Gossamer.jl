import utf8proc_jll

# Changes:
# * Ccall into utf8proc_jll instead of libjulia.
const libutf8proc_path = utf8proc_jll.get_libutf8proc_path()
@device_override @inline function Base.Unicode.isgraphemebreak!(state::Ref{Int32}, c1::AbstractChar, c2::AbstractChar)
    if Base.ismalformed(c1) || Base.ismalformed(c2)
        state[] = 0
        return true
    end

    ccall((:utf8proc_grapheme_break_stateful, libutf8proc_path), Bool,
          (UInt32, UInt32, Ref{Int32}), c1, c2, state)
end
