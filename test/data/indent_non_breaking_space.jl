## Normal space, no heuristics to preserve this.
x = [-1  2
      2 -1]
#
x = [-1  2
     2 -1]
## Non breakable space before the `2` on the second line is preserved.
x = [-1  2
      2 -1]
##
x=[-1  2
    2 -1]
#
x = [-1  2
      2 -1]
## Another case of non breakable space.
y[i, j] = ((1 - α) * (1 - β) * x[i1, j1] +
           (1 - α) *    β    * x[i1, j2] +
              α    * (1 - β) * x[i2, j1] +
              α    *    β    * x[i2, j2])
## There's exotic space at the start of the third row.
function f()
    y = x +
    x
end
#
function f()
    y = x +
            x
end
##
function f()
    y = x +
            x
end
