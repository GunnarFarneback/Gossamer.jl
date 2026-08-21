## Basic let constructions.
let
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
let x = 1
x
end
#
let x = 1
    x
end
##
let x = 1,
y = 2
end
#
let x = 1,
    y = 2
end
##
let x = 1,
y = 2

x    
end
#
let x = 1,
    y = 2

    x
end
## Let construction assigned to a variable
zz = let x = 1,
y = 2
x
end
#
zz = let x = 1,
         y = 2
    x
end
## Also accept
zz = let x = 1,
         y = 2

         x
     end
## and test with extra first line comment:
zz = let x = 1,
         y = 2

# comment
         x
     end
## Let construction deeper in the tree
if true
    let x = 1,
        y = 2

        x
    end
end
## Newline insertion.
let x = 1,
    y = 3
    f(x + y)
end
#
let x = 1,
    y = 3

    f(x + y)
end
