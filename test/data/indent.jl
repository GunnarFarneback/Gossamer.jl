for x in X
x
end
#
for x in X
    x
end
##
if x
      y
end
#
if x
    y
end
##
function gazonk(x,
      y)
    return x
    end
#
function gazonk(x,
                y)
    return x
end
##
function gazonk(x,
      y
 )
    return x
    end
#
function gazonk(x,
                y
                )
    return x
end
##
gazonk(
x,
y) = x
#
gazonk(
    x,
    y) = x
##
gazonk(
x,
y
) = x
#
gazonk(
    x,
    y
) = x
## Accept this version too.
gazonk(
    x,
    y
    ) = x
##
if x
1
else
3
end
#
if x
    1
else
    3
end
##
if x
1
elseif y
2
else
3
end
#
if x
    1
elseif y
    2
else
    3
end
##
module M
    x
end
#
module M
x
end
##
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
let x = 1
x
end
#
let x = 1
    x
end
##
let
x = 1
x
end
#
let
    x = 1
    x
end
##
import x,
       y
##
import x,
    y
##
import x: y,
          z
##
import x: y,
       z
##
import x: y,
    z
##
using x,
      y
##
using x,
    y
##
using x: y,
         z
##
using x: y,
      z
##
using x: y,
    z
##
export x,
       y
##
export x,
    y
##
public x,
       y
##
public x,
    y
##
x = Dict(1 => 2,
         3 => 4)
##
x = Dict(
    1 => 2,
    3 => 4)
##
x = Dict(
    1 => 2,
    3 => 4
)
##
@test x ==
    y
##
expr = :(begin
             x
         end)
##
expr = :(
    begin
        x
    end)
##
expr = :(
    begin
        x
    end
)
##
d = Dict(1 => quote
             x
         end)
##
UInt8[0x00,
      0x01
      ]
##
x = [
    0,
    [
        1
    ]
]
##
xxxxxxxxxxxx = 1 +
    2
##
return x |> sin |>
    exp
## Allow hanging indents.
xxxxxxxxxxxx = 1 +
               2
##
return x |> sin |>
       exp
## There's a TAB lurking here.
function f(x)
	x
end
#
function f(x)
    x
end
##
if true
    begin
        x
    end
end
##
if true
    let x = x
        x
    end
end
##
@generated function
    f(x)

    return :x
end
##
return esc(quote
               :x
           end)
##
return esc(quote
    :x
end)
##
for x in 1:2,
    y in 3:4
    f(x + y)
end
#
for x in 1:2,
    y in 3:4

    f(x + y)
end
##
if true && false &&
    true

end
##
@testset "" begin
    @test f(x,
            y) ==
        z
end
##
@testset "" begin
    @test f(x,
            y) ==
            z
end
#
@testset "" begin
    @test f(x,
            y) ==
        z
end
##
y = x ? 1 :
        2
##
y = x ? 1 :
    2
