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
yy = Dict(x
          for x in X)
##
yy = Dict(x
          for x in X
          if true)
##
yy = Dict(x
          for x in X,
              y in Y)
##
yy = Dict(x
          for x in X,
              y in Y
          if true)
##
x = f((x
       for x in x),
      init = 0)
##
x = f((x
       for x in x
       if true),
      init = 0)
