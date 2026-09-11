## using as the same formatting as import, so just sanity check a few
## samples here.
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
