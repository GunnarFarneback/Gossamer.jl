return esc(quote
    :x
end)
##
f(x, (y,
    z),
w)
#
f(x, (y,
    z),
    w)
##
x=[[
    x],
    ]
#
x = [[
    x],
]
##
@foo x ->
f(x) =
    1
##
y = f(x = [
    1x,
    2x]
)
##
function f()
    return (function ()
        return 0
    end, function ()
        return 1
    end)
end
##
begin
    yy = f(f(f(f(x,
        y)))[
        1,
        2])
end
##
begin
    begin
        begin
    end end end
#
begin
    begin
        begin
end end end
##
begin
    begin begin
        1
    end end
end
##
y =
    x[zz{
        w
    }(
        1
    )]
##
z = f(; x = [
    0 0
    0 0
    1 1
], y = [
    0 0
    0 0
    1 1
])
##
f(g() do x
    y
end, 1, g() do x
    if z
        0
    else
        1
    end
end, 2)
##
function f()
    y = g(x => begin
        x
    end for z in Z)
end
##
function f(x)
    quote
        let c = g(x) do y
            h(y)
        end
        function i(x)
        end
        end
    end
end
##
@test f() do x
x
end ≈ let
x
end
#
@test f() do x
    x
end ≈ let
    x
end
##
ffffff(x -> begin
    try
        0
    catch
    end
end) do x
    1
end
