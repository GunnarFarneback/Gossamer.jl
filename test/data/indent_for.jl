for x in X
x
end
#
for x in X
    x
end
##
for x in 1:2,
    y in 3:4
    f(x + y)
end
#
for x in 1:2,
    y in 3:4

    f(x + y)
end
##
if true for x in X
        x
    end
end
##
true && for x in X
    x
end
##
true &&
    for x in X
        x
    end
##
true && (for x in X
             x
         end)
##
true && (
    for x in X
        x
    end)
##
true && (for x in X
             x
         end
         )
##
true && (
    for x in X
        x
    end
)
##
begin
    for h in H,
        w in W
    end
end
##
for x in X,
y in Y
end
#
for x in X,
    y in Y
end
## Questionable test case. The element should rather have another indentation.
for x in [
    1
    ]
    x
end
##
for x in X
    if x && (
           x == x ||
                x
)
    end
end
#
for x in X
    if x && (
            x == x ||
                x
        )
    end
end
##
for x in (
        1:2,
        3
    )
    x
end
