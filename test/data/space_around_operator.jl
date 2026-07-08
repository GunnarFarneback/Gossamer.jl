z=-x+y
#
z = -x + y
##
1+2*3+4
#
1 + 2 * 3 + 4
##
1*2+3*4
#
1 * 2 + 3 * 4
##
x^y
#
x^y
##
x ^ y
##
x.+y
#
x .+ y
##
x.^y
#
x.^y
##
x. +, y
#
x. +, y
##
x+=y
#
x += y
##
x.+=y
#
x .+= y
##
x>>=y
#
x >>= y
##
x.<<=y
#
x .<<= y
##
T<:Int
##
T <: Int
##
function f(x::T) where T<:Integer
end
##
function f(x::T) where T <: Integer
end
##
reduce(+, x)
##
f(*, +, *)
##
using F: +, -, *
##
struct M
    x::Int
end
## Accept this?
struct M
    x  ::Int
    yz ::UInt
end
##
f(x ::Int)
#
f(x::Int)
##
y = x * -1
##
y = (x *
     -1)
##
y = (x
     - 1)
##
1:2
##
1:2:3
##
x = true ? false : true
##
x[1:end-1]
##
x[1:(end-1)]
##
f(in; out)
f(+, 3)
f(+; a)
##
[(N-1:-1:1);N]
#
[(N-1:-1:1); N]
##
x=1+(y.a/2)
#
x = 1 + (y.a / 2)
##
1//2
##
1 // 2
##
1 //2
#
1//2
##
1// 2
#
1//2
##
x  ::Int
#
x::Int
##
x::   Int
#
x::Int
## Don't mess with strings.
"a$(b)c"
## Accept no-space division of literals.
1/2
## This is not such a case.
1/2^(x - 1)
#
1 / 2^(x - 1)
