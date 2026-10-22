if x
      y
end
#
if x
    y
end
##
if x
1
else
3
end
#
if x
    1
else
    3
end
##
if x
1
elseif y
2
else
3
end
#
if x
    1
elseif y
    2
else
    3
end
##
if true
    begin
        x
    end
end
##
if true && false &&
    true
    false
end
#
if true && false &&
    true

    false
end
##
if x == +
    1
end
##
if true &&
!false
x
end
#
if true &&
    !false

    x
end
##
if a ||
(c &&
(d || e))
end
#
if a ||
    (c &&
     (d || e))
end
## Can skip empty line after `end` and closing brackets.
if begin
        x &&
            y
    end
    z
end
##
if (
    x &&
    y
    )
    z
end
##
if (x
    || x)
    if x
        x
    end
end
#
if (x
    || x)

    if x
        x
    end
end
##
function f()
  x = if y
    z
  else
    z
  end
end
#
function f()
    x = if y
        z
    else
        z
    end
end
##
if xxxxx && (
x
)
end
#
if xxxxx && (
        x
    )
end
