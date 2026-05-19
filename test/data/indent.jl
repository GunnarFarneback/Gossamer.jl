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
z = let x = 1,
y = 2
x
end
#
z = let x = 1,
        y = 2
    x
end
## Also accept
z = let x = 1,
        y = 2

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
function
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
let x = 1,
    y = 3
    f(x + y)
end
#
let x = 1,
    y = 3

    f(x + y)
end
##
if true && false &&
    true
    false
end
#
if true && false &&
    true

    false
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
yyy = x ? 1 :
          2
##
yyy = x ? 1 :
      2
##
yyy = x ? 1 :
    2
##
xxxxxxxxxxxxx =
    yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy =
    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz =
    wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww = 2
## First line spaces.
  1
#
1
##
   
1
#

1
##
if true for x in X
        x
    end
end
##
true && for x in X
    x
end
##
true &&
    for x in X
        x
    end
##
true && (for x in X
             x
         end)
##
true && (
    for x in X
        x
    end)
##
true && (for x in X
             x
         end
         )
##
true && (
    for x in X
        x
    end
)
##
if true
if true
if true
1
elseif false
2
else
3
end

try
x
catch e
e
finally
0
end
end
end
#
if true
    if true
        if true
            1
        elseif false
            2
        else
            3
        end

        try
            x
        catch e
            e
        finally
            0
        end
    end
end
##
f(x) = (g(x,
          x); x)
##
if x == +
    1
end
##
yy = ff(
    #
    x)
##
f(g) = g * g'
1
##
x = ' '
y
##
f() do
    g(x,
      y)
end
##
begin
    for h in H,
        w in W
    end
end
##
Dict(x
     for x in X)
##
Dict(x
     for x in X
     if true)
##
Dict(x
     for x in X,
         y in Y)
##
Dict(x
     for x in X,
         y in Y
     if true)
##
if true &&
!false
x
end
#
if true &&
    !false

    x
end
