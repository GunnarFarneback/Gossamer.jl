import JuliaSyntax

# Changes:
# * Ccall to `jl_strtod_c` replaced by ccall to `strtod` in Libc. This
#   is incorrect since it makes parsing locale dependent.
@device_override @inline function JuliaSyntax._unsafe_parse_float(::Type{Float64}, ptr, strsize)
    Libc.errno(0)
    endptr = Ref{Ptr{UInt8}}(C_NULL)
    x = ccall(:strtod, Cdouble, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, endptr)
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
# * Ccall to `jl_strtof_c` replaced by ccall to `strtof` in Libc. This
#   is incorrect since it makes parsing locale dependent.
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
        x = Float32(ccall(:strtod, Cdouble, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, endptr))
        if isinf(x)
            status = :overflow
            # Underflow not detected, but that will only be a warning elsewhere.
        end
    else
        x = ccall(:strtof, Cfloat, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, endptr)
    end
    JuliaSyntax.@check endptr[] == ptr + strsize
    if Libc.errno() == Libc.ERANGE
        status = abs(x) < 1 ? :underflow : :overflow
    end
    return (x, status)
end
