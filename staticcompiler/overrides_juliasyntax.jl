import JuliaSyntax

# Changes:
# * Ccall to `jl_strtod_c` replaced by ccall to `strtod` in Libc via
#   the `_strtod_c` function below.
@device_override @inline function JuliaSyntax._unsafe_parse_float(::Type{Float64}, ptr, strsize)
    Libc.errno(0)
    endptr = Ref{Ptr{UInt8}}(C_NULL)
    x = _strtod_c(ptr, endptr)
    JuliaSyntax.@check endptr[] == ptr + strsize
    status = :ok
    if Libc.errno() == Libc.ERANGE
        # strtod man page:
        # * If  the  correct  value  would cause overflow, plus or
        #   minus HUGE_VAL, HUGE_VALF, or HUGE_VALL is returned and
        #   ERANGE is stored in errno.
        # * If the correct value would cause underflow, a value with
        #   magnitude no larger than DBL_MIN, FLT_MIN, or LDBL_MIN is
        #   returned and ERANGE is stored in errno.
        status = abs(x) < 1 ? :underflow : :overflow
    end
    return (x, status)
end

# Changes:
# * Ccall to `jl_strtof_c` replaced by ccall to `strtof` in Libc via
#   the `_strtof_c` function below.
# * Same for `jl_strtod_c`, although this is only used on Windows,
#   which isn't supported by StaticRuntime yet anyway.
@inline function JuliaSyntax._unsafe_parse_float(::Type{Float32}, ptr, strsize)
    # Convert float exponent 'f' to 'e' for strtof, eg, 1.0f0 => 1.0e0
    # Presumes we can modify the data in ptr!
    for p in ptr+strsize-1:-1:ptr
        if unsafe_load(p) == UInt8('f')
            unsafe_store!(p, UInt8('e'))
            break
        end
    end
    Libc.errno(0)
    endptr = Ref{Ptr{UInt8}}(C_NULL)
    status = :ok
    @static if Sys.iswindows()
        # Call strtod here and convert to Float32 on the Julia side because
        # strtof seems buggy on windows and doesn't set ERANGE correctly on
        # overflow. See also
        # https://github.com/JuliaLang/julia/issues/46544
        x = _strtod_c(ptr, endptr)
        if isinf(x)
            status = :overflow
            # Underflow not detected, but that will only be a warning elsewhere.
        end
    else
        x = _strtof_c(ptr, endptr)
    end
    JuliaSyntax.@check endptr[] == ptr + strsize
    if Libc.errno() == Libc.ERANGE
        status = abs(x) < 1 ? :underflow : :overflow
    end
    return (x, status)
end

# Strictly this should call `strtod_l` with a locale object for the
# "C" locale. Creating the locale object is a bit hard to do outside
# of C, however, and the "C" locale should be set by default when the
# program is started anyway.
function _strtod(ptr, endptr)
    return ccall(:strtod, Cdouble, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, endptr)
end

# Same comment as above.
function _strtof(ptr, endptr)
    return ccall(:strtof, Cdouble, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, endptr)
end
