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
