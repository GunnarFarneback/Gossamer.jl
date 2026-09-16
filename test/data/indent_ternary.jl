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
