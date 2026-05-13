## These tests test formatting of lines with comments. Since test case
## organization is also done with comments, it may take some care to
## distingush what is what. The key here is that the latter is done
## with double number signs optionally followed by text and
## (optionally) by single number signs alone on a line.
##
## The basic idea is that whole line comments should be indented like
## the following code line.
 # a
if true
 # b
    false
end
#
# a
if true
    # b
    false
end
## However, make an exception for comments starting in the first
## column. These may be used to comment out code, and indenting them
## will likely not turn out nicely.
if true
#    false
# 
#    !false
    true
end
