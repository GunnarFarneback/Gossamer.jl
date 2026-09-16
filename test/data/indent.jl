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
## Accept modules both with and without indentation.
module M
    x
end
##
module M
x
end
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
return esc(quote
               :x
end)
#
return esc(quote
               :x
           end)
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
macro m(x)
esc(x)
end
#
macro m(x)
    esc(x)
end
##
fffffff(;
a = 1,
b = 2
)
#
fffffff(;
    a = 1,
    b = 2
)
##
fffffff(; a = 1,
b = 2)
#
fffffff(; a = 1,
        b = 2)
##
y = (
x
)
#
y = (
    x
)
##
y = (;
x
)
#
y = (;
    x
)
##
function f(x)
    # x
    f(x; x = [1,
              1],
      y = 1)
end
#
function f(x)
    # x
    f(x; x = [1,
              1],
      y = 1)
end
##
function f(x;
           y) where {S,
                    T}
end
#
function f(x;
           y) where {S,
                     T}
end
##
x = [x +
     x; f(x,
     x)]
#
x = [x +
     x; f(x,
          x)]
##
f(x,
y) = g(x,
x)
#
f(x,
  y) = g(x,
         x)
##
if true
x = [
    1:2,
    3:4
]
end
#
if true
    x = [
        1:2,
        3:4
    ]
end
##
"""
Read the tutorial at $(abspath(dirname(@__DIR__), "test",
"tutorial.jl")) or
"""
##
ccccccccxxxxx = f(x, ggggg(
ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
                           ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
ccccccccccccccccccccccccccccccccccccccccccccccccccccy
),
x
)
#
ccccccccxxxxx = f(x, ggggg(
        ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
        ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
        ccccccccccccccccccccccccccccccccccccccccccccccccccccy
    ),
    x
)
##
ccccccccxxxxx = f(x, ggggg(x,
ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
                           ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
ccccccccccccccccccccccccccccccccccccccccccccccccccccy
),
x
)
#
ccccccccxxxxx = f(x, ggggg(x,
                           ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
                           ccccccccccccccccccccccccccccccccccccccccccccccccccccx,
                           ccccccccccccccccccccccccccccccccccccccccccccccccccccy
                           ),
                  x
                  )
