f() do
x
end
#
f() do
    x
end
##
f() do x
x
end
#
f() do x
    x
end
##
xxxxxx =
    f() do y
        z
    end
##
xxxxxx +=
    f() do y
        z
    end
##
f() do
    g(x,
      y)
end
##
yyy = f() do x
    x

    x
end
##
yyy = f() do x
    g(x)

    x
end
##
yyy = f() do x
x
end
#
yyy = f() do x
    x
end
##
yyy = f() do x
          x
end
#
yyy = f() do x
          x
      end
##
fffffff(x,
        y) do z
    z
end
##
function g()
    if x
    elseif y && f() do x
            return x
        end
    end
end
##
function f()
if true
    g() do
        yyy = h() do
           x()
         end
        return y
    end
end
end
#
function f()
    if true
        g() do
            yyy = h() do
                x()
            end
            return y
        end
    end
end
##
function parse(::Type{Float64}, s::AbstractString, r::RoundingMode)
    a = setprecision(BigFloat, 53) do
            setrounding(BigFloat, r) do
                parse(BigFloat, s)
            end
        end

    return Float64(a, r)
end
