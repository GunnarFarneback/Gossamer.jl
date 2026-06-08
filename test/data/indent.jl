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
## Accept modules both with and without indentation.
module M
    x
end
##
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
xxxxxx +=
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
import x:
    y,
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
using x:
    y,
    z
##
export x,
       y
##
export x,
    y
##
export
    x,
    y
##
public x,
       y
##
public x,
    y
##
public
    x,
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
for x in X,
y in Y
end
#
for x in X,
    y in Y
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
##
y = f() do x
    x

    x
end
## Remove trailing space regardless whether indentation changes.
if false 
0
else 
    1
end
#
if false
    0
else
    1
end
## Always eliminate TAB indentation.
begin
				1
end
	2
#
begin
    1
end
2
## Another TAB case.
	
	x
#

x
## TAB and newline only.

	
#


## Hanging indent should be preferred.
yyyyy = (x +
          y)
#
yyyyy = (x +
         y)
## Don't insist on adding an empty line in empty clauses.
try
    x
catch e
finally
end

try
catch e
finally
end

if true
elseif false
else
end

for i in I
end

while false
end
##
esc(quote
tmp = min(x[$i], x[$j])
end)
#
esc(quote
        tmp = min(x[$i], x[$j])
    end)
##
ex = quote
    x

    y
end
##
y = (x
    + a * x
    + x)
#
y = (x
     + a * x
     + x)
##
if a ||
(c &&
(d || e))
end
#
if a ||
    (c &&
     (d || e))
end
##
fffffff(x,
        y) do z
    z
end
## There's a trailing space after the `y`.
if x ||
    y 
    return
end
#
if x ||
    y

    return
end
##
while let
x
end
end

while begin
x
end
end

for x in let
X
end
end

for x in begin
X
end
end
#
while let
        x
    end
end

while begin
        x
    end
end

for x in let
        X
    end
end

for x in begin
        X
    end
end
##
function g()
    if x
    elseif y && f() do x
            return x
        end
    end
end
## Can skip empty line after `end` and closing brackets.
if begin
        x &&
            y
    end
    z
end
##
if (
    x &&
    y
    )
    z
end
##
for x in [
    1
    ]
    x
end
##
for x in X
    if x && (
           x == x ||
                x
)
    end
end
#
for x in X
    if x && (
        x == x ||
            x
    )
    end
end
##
x = f((x
       for x in x),
      init = 0)
##
x = f((x
       for x in x
       if true),
      init = 0)
