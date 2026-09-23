yyy = x ? 1 :
          2
##
yyy = x ? 1 :
      2
##
yyy = x ? 1 :
    2
##
xx ? x :
     x
##
function f()
    yy =
        x ? x :
        #
        x ? x :

        x ? x : y
end
##
function f1()
    yy =
        x ? x :
        #
        x ? x :
         x ? x : y
end
#
function f1()
    yy =
        x ? x :
        #
        x ? x :
        x ? x : y
end
##
function f2()
    yy =
        x ? x :
        #
        x ? x :
###
         x ? x : y
end
#
function f2()
    yy =
        x ? x :
        #
        x ? x :
###
        x ? x : y
end
##
function f3()
    yy =
        x ? x :
        #
        x ? x :
 #=
 =#
         x ? x : y
end
#
function f3()
    yy =
        x ? x :
        #
        x ? x :
 #=
 =#
        x ? x : y
end
## Primary
f(xxx, xxx ? xxx :
xxx)
#
f(xxx, xxx ? xxx :
             xxx)
## Secondary
f(xxx, xxx ? xxx :
       xxx)
## Secondary
f(xxx, xxx ? xxx :
  xxx)
## Secondary (left indent)
f(xxx, xxx ? xxx :
    xxx)
## Primary
f(xxx, xxx ? xxx :
xxx ? xxx : xxx)
#
f(xxx, xxx ? xxx :
       xxx ? xxx : xxx)
## Secondary
f(xxx, xxx ? xxx :
             xxx ? xxx : xxx)
## Secondary
f(xxx, xxx ? xxx :
  xxx ? xxx : xxx)
## Secondary
f(xxx, xxx ? xxx :
    xxx ? xxx : xxx)
## Newline before ? and :
y = (xxxxxxxx
? 1
: 2)
#
y = (xxxxxxxx
         ? 1
         : 2)
##
f(x, (xxx ?
      1 : 2))
##
f(x) ?
    y :
  z
#
f(x) ?
    y :
    z
##
function f(x)
    y =
    # a
    f(x) ? f(x) :
    # b
    f(x, xxx) && g(x) ? h(x) :
    # c
    (f(x) || g(x)) && !x ? h(x) :
    # d
    f(x) ? 2 : 1
end
#
function f(x)
    y =
        # a
        f(x) ? f(x) :
        # b
        f(x, xxx) && g(x) ? h(x) :
        # c
        (f(x) || g(x)) && !x ? h(x) :
        # d
        f(x) ? 2 : 1
end
