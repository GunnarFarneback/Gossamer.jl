import OptParse

# Changes:
# * Replace `Core.stderr` with `StaticRuntime.STDERR` in the print statements.
@device_override OptParse.@autospecialize pp function OptParse.optparse(pp::OptParse.AbstractParser{T, E}, args::Vector{String}; progname = "") where {T, E}
    UE = OptParse.joinerr(E, OptParse.MainError)
    mayberes = OptParse.tryoptparse(pp, args)::OptParse.Result{T, UE}

    if OptParse.is_error(mayberes)
        errmsg = sprint(
            showerror, OptParse.ParseException{typeof(pp), UE}(
                pp, args, OptParse.ParseError{UE}(OptParse.unwrap_error(mayberes)), String(progname)
            )
        )
        print(STDERR, "Error: ")
        println(STDERR, errmsg)
        return nothing
    end

    return OptParse.unwrap(mayberes)
end

# Changes:
# * Add the `println` statement. This is undesirable to have but for
#   incomprehensible reasons avoids `TypeError: type assertion failed`
#   when an optional argument is omitted. Be aware that just
#   `println()` or `print("")` does not have this effect, which is
#   also beyond weird.
@device_override OptParse.@autospecialize p function OptParse.complete(
        p::OptParse.ModWithDefault{T, E, OptParse.WithDefaultState{S}, P},
        st::OptParse.WithDefaultState{S}
    ) where {T, E, S, P <: OptParse.AbstractParser{<:Any, <:Any, S}}

    println("")

    childstate = OptParse.@cases st begin
        NotMatched => return OptParse.Result{T, E}'.Ok(p.default)
        Matched(childstate) => childstate
    end

    result = OptParse.complete(p.parser, childstate)
    if OptParse.is_error(result)
        return OptParse.Result{T, E}'.Err(OptParse.unwrap_error(result))
    end

    # Rewrap as the widened output type of the modifier.
    return OptParse.Result{T, E}'.Ok(OptParse.unwrap(result))
end

