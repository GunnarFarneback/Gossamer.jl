f(x, a=b)
##
f(x, a = b)
##
f(x, a= b)
#
f(x, a = b)
##
f(x, a =b)
#
f(x, a = b)
## Treat named tuples the same way.
(; x, a=b)
##
(; x, a = b)
##
(; x, a= b)
#
(; x, a = b)
##
(; x, a =b)
#
(; x, a = b)
##
(x=1, y = 2)
## And macro calls.
@f x a=b
##
@f x a = b
##
@f x a= b
#
@f x a = b
##
@f x a =b
#
@f x a = b
## It becomes a bit weird if space is added around `*` but not `=`.
## (Rule is to only allow keywords without space if the value is an
## identifier or a literal.)
f(; a=2*c)
#
f(; a = 2 * c)
##
(; a=2*c)
#
(; a = 2 * c)
