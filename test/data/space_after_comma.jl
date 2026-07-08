f(1,2)
#
f(1, 2)
##
f(1,2,)
#
f(1, 2,)
##
f(1,2, 3,4, 5)
#
f(1, 2, 3, 4, 5)
##
f(g(1,2),3, x + y)
#
f(g(1, 2), 3, x + y)
##
f(x;y)
#
f(x; y)
##
f(x;y = 0)
#
f(x; y = 0)
##
f(x,y) = x + y
#
f(x, y) = x + y
##
f(x,y = 0) = x + y
#
f(x, y = 0) = x + y
##
f(x;y) = x + y
#
f(x; y) = x + y
##
f(x;y = 0) = x + y
#
f(x; y = 0) = x + y
##
function f(x::T,y::S) where {S <: Integer,T <: AbstractFloat}
    return x + y
end
#
function f(x::T, y::S) where {S <: Integer, T <: AbstractFloat}
    return x + y
end
##
(1,2)
#
(1, 2)
##
(a = 1,b = 2)
#
(a = 1, b = 2)
##  Allow skipping space after semicolon directly following parenthesis.
(;a = 1,b = 2)
#
(;a = 1, b = 2)
##
(; a = 1,b = 2)
#
(; a = 1, b = 2)
##
(a = 1,)
#
(a = 1,)
##
(;a = 1)
##
(; a = 1)
##
a,b = b,a
#
a, b = b, a
##
(;a,b) = c
#
(;a, b) = c
##
(; a,b) = c
#
(; a, b) = c
##
[1,2]
#
[1, 2]
##
f[x,y] = Int[1,2]
#
f[x, y] = Int[1, 2]
##
[f(x,y);g(x,y,z)]
#
[f(x, y); g(x, y, z)]
## Assume this is an ordering typo and swap it.
f(x ,y)
#
f(x, y)
## This too.
f(x ;y)
#
f(x; y)
## And this, although it's a weird case.
f(x, ;y)
#
f(x,; y)
##
Array{T,2}
#
Array{T, 2}
##
a=1;b=2
#
a = 1; b = 2
##
print(1);println(2)
#
print(1); println(2)
##
x = [1 ;; 2]
##
import a,b
#
import a, b
##
x = [1, 2,]
##
global a,b
#
global a, b
