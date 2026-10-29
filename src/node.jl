using JuliaSyntax: JuliaSyntax, parseall, GreenNode, Kind, @K_str

mutable struct Node
    # Empty for leaf nodes.
    children::Vector{Node}
    # Cached value of isempty(children), for faster lookup.
    is_leaf::Bool
    # Depth within tree. Root node is at depth 0.
    depth::Int
    # Sibling index. Unless `node` is the root node, it must always
    # hold that `node === node.parent[node.index]`.
    index::Int
    # Row in source. Never changes, only used for debugging. Nodes
    # inserted while formatting have row number zero.
    row::Int
    # Starting column in source. Used for determining indentation.
    # Must always be kept up to date, unless `column_is_current` is false.
    # Use `get_column` to obtain valid information.
    column::Int
    # Set to false if column information is outdated. If this is false
    # for a node, it must also be false for all following nodes on the
    # same row. (This scheme avoids quadratic complexity, e.g. for
    # long lines of comma-separated values without space.)
    column_is_current::Bool
    # The source text covered by this node. For non-leaf nodes this is
    # always the original source.
    text::Union{String, SubString{String}}
    # Index to first newline character in `text`. Set to zero if no
    # newline present.
    newline_index::Int
    # Kind of corresponding GreenNode.
    kind::Kind
    # Root node points to itself.
    parent::Node

    function Node(children::Vector{Node}, index::Int, row::Int, column::Int,
                  text::Union{String, SubString{String}}, kind::Kind,
                  parent::Union{Nothing, Node})
        if isnothing(parent)
            node = new(children, true, 0, index, row, column, true, text,
                       0, kind)
            node.parent = node
        else
            node = new(children, true, parent.depth + 1, index, row, column,
                       true, text, 0, kind, parent)
        end
        return node
    end
end

function Base.show(io::IO, node::Node)
    print_node(io, node)
end

# TODO: Traverse nodes instead of recursing.
function print_node(io::IO, node::Node)
    print(io, lpad(node.row, 5), " ")
    print(io, lpad(get_column(node), 5), " ")
    if isempty(node.children)
        print(io, rpad(string(" "^node.depth, kind(node)), 30), " ")
        if kind(node) in [K"Whitespace", K"NewlineWs"]
            print(io, "\"", escape_string(node.text), "\"")
        else
            print(io, node.text)
        end
    else
        println(io, rpad(string(" "^node.depth, "[", kind(node), "]"), 30), " ")
        for (i, child) in enumerate(node.children)
            print_node(io, child)
            i < length(node.children) && println(io)
        end
    end
end

# Short string description of a node. Intended for debug prints.
function _string(node::Node)
    k = string(kind(node))
    if !is_leaf(node)
        k = "[$k]"
    end
    return string(node.row, " ", get_column(node), " ", k)
end

kind(node::Node) = node.kind
iskind(node::Node, kinds::Kind...) = any(==(kind(node)), kinds)
is_root(node) = node.parent === node
is_leaf(node) = node.is_leaf
is_whitespace(node) = iskind(node, K"Whitespace", K"NewlineWs")
is_literal(node) = JuliaSyntax.is_literal(kind(node))
is_first_sibling(node) = first(node.parent.children) === node
is_last_sibling(node) = last(node.parent.children) === node

# is node1 an ancestor of node2?
function is_ancestor_of(node1::Node, node2::Node)
    while node2.parent !== node2
        node2 = node2.parent
        node2 === node1 && return true
    end
    return false
end

function green_to_node(green::GreenNode, raw::AbstractString)
    pos, row, column = 1, 1, 1
    root = Node(Node[], 1, row, column, "", JuliaSyntax.kind(green.head),
                nothing)
    stack = [(green, root, 1)]
    while !isempty(stack)
        green, node, i = pop!(stack)
        if !isnothing(green.children) && i < length(green.children)
            push!(stack, (green, node, i + 1))
        end
        if isnothing(green.children) || isempty(green.children)
            #text = raw[pos:prevind(raw, pos + green.span)]
            text = unsafe_string(pointer(raw, pos), green.span)
            pos += green.span
            node.text = text
            if contains(text, '\n')
                row += count(==('\n'), text)
                column = 1 + length(last(rsplit(text, "\n", limit = 2)))
                node.newline_index = findfirst(==('\n'), text)
            else
                column += length(text)
            end
        else
            node.is_leaf = false
            if i <= length(green.children)
                green_child = green.children[i]
                grandchildren = Node[]
                if !isnothing(green_child.children)
                    sizehint!(grandchildren, length(green_child.children))
                end
                j = length(node.children) + 1
                child = Node(grandchildren, j, row, column, "",
                             JuliaSyntax.kind(green_child.head), node)
                push!(node.children, child)
                push!(stack, (green_child, child, 1))
            end
        end
    end

    return root
end

function parse_string(raw)
    green = parseall(GreenNode, raw; filename = "", ignore_warnings = true)
    node = green_to_node(green, raw)
    return node
end

function write_node(io::IO, node::Node)
    if isempty(node.children)
        print(io, node.text)
    else
        for child in node.children
            write_node(io, child)
        end
    end
end

function write_node(filename::AbstractString, node::Node)
    open(filename, "w") do io
        write_node(io, node)
    end
end

function write_node(node::Node)
    buf = IOBuffer()
    write_node(buf, node)
    return String(take!(buf))
end

# Return node if it is a leaf. Otherwise descend the first child until
# reaching a leaf node.
function leftmost_leaf(node)
    while !is_leaf(node)
        node = first(node.children)
    end
    return node
end

# Return node if it is a leaf. Otherwise descend the last child until
# reaching a leaf node.
function rightmost_leaf(node)
    while !is_leaf(node)
        node = last(node.children)
    end
    return node
end

# Move to the preceding node, parent included in preceding nodes but
# not children. Return the root node if there is no preceding node.
function move_left(node)
    is_root(node) && return node
    if node.index > 1
        return rightmost_leaf(node.parent.children[node.index - 1])
    end
    return node.parent
end

# Move to the following node, children included in following nodes but
# not parent. Return the root node if there is no following node.
function move_right(node)
    is_leaf(node) || return first(node.children)
    while node.index == length(node.parent.children)
        node = node.parent
        is_root(node) && return node
    end
    return node.parent.children[node.index + 1]
end

# Move to the following node but skip children. Return the root node
# if there is no following node.
function move_right_no_descent(node)
    while node.index == length(node.parent.children)
        node = node.parent
        is_root(node) && return node
    end
    return node.parent.children[node.index + 1]
end

# Move to the preceding sibling, back up to parent if out of siblings.
# Return the root node if there is nowhere left to move.
function move_left_no_descent(node)
    is_root(node) && return node
    if node.index > 1
        return node.parent.children[node.index - 1]
    end
    return node.parent
end

# Find the nearest preceding leaf node. Return the root node if there
# is no preceding leaf.
function move_left_to_leaf(node)
    while !is_root(node)
        if node.index > 1
            return rightmost_leaf(node.parent.children[node.index - 1])
        end
        node = node.parent
    end
    return node
end

# Combination of the two functions above.
function move_left_no_descent_to_leaf(node)
    while !is_root(node)
        if node.index > 1
            node = node.parent.children[node.index - 1]
        else
            node = node.parent
        end
        is_leaf(node) && break
    end
    return node
end

# Find the nearest following leaf node. Return the root node if there
# is no following leaf.
function move_right_to_leaf(node)
    is_leaf(node) || return leftmost_leaf(node)
    while !is_root(node)
        if node.index < length(node.parent.children)
            return leftmost_leaf(node.parent.children[node.index + 1])
        end
        node = node.parent
    end
    return node
end

function insert_leaf_node!(node, position, kind, text)
    leaf = Node(Node[], position, 0, 0, text, kind, node)
    insert!(node.children, position, leaf)
    # Leaf is in place, but we must update sibling indices and column
    # numbers for later nodes.
    for i in (position + 1):length(node.children)
        node.children[i].index = i
    end
    invalidate_column_for_rest_of_row(leaf)
    # Invalidate ourselves too, since we don't have a correct column number.
    leaf.column_is_current = false
    return leaf
end

# It is assumed that this will never remove the last child of a
# node. If it did it would need to also update node.is_leaf.
function remove_child!(parent, position)
    deleteat!(parent.children, position)
    # Child has been removed, but we must update sibling indices and
    # column numbers for later nodes.
    for i in position:length(parent.children)
        parent.children[i].index = i
    end
    invalidate_column_for_rest_of_row(parent)
    return
end

# Move a first child node up to parent.
function move_first_sibling_out_of_node!(node)
    @assert !is_root(node)
    @assert is_first_sibling(node)
    parent = node.parent
    popfirst!(parent.children)
    for i in eachindex(parent.children)
        parent.children[i].index = i
    end
    parent.is_leaf = isempty(parent.children)
    node.parent = parent.parent
    node.depth -= 1
    index = parent.index
    insert!(parent.parent.children, index, node)
    for i in index:length(parent.parent.children)
        parent.parent.children[i].index = i
    end
end

# Move a last child node up to parent.
function move_last_sibling_out_of_node!(node)
    @assert !is_root(node)
    @assert is_last_sibling(node)
    parent = node.parent
    pop!(parent.children)
    parent.is_leaf = isempty(parent.children)
    node.parent = parent.parent
    node.depth -= 1
    index = parent.index
    insert!(parent.parent.children, index + 1, node)
    for i in index:length(parent.parent.children)
        parent.parent.children[i].index = i
    end
end

# Move a node to be first child of the immediately following
# sibling node.
function move_node_into_following_sibling!(node)
    @assert !is_root(node)
    @assert !is_last_sibling(node)
    parent = node.parent
    index = node.index
    next = node.parent.children[index + 1]
    deleteat!(parent.children, index)
    for i in index:length(parent.children)
        parent.children[i].index = i
    end
    node.parent = next
    node.depth += 1
    pushfirst!(next.children, node)
    for i in eachindex(next.children)
        next.children[i].index = i
    end
    next.is_leaf = false
end

# Move a node to be last child of the immediately previous
# sibling node.
function move_node_into_previous_sibling!(node)
    @assert !is_root(node)
    @assert !is_first_sibling(node)
    parent = node.parent
    index = node.index
    prev = node.parent.children[index - 1]
    deleteat!(parent.children, index)
    for i in index:length(parent.children)
        parent.children[i].index = i
    end
    node.parent = prev
    node.depth += 1
    push!(prev.children, node)
    node.index = length(prev.children)
    prev.is_leaf = false
end

function refresh_parent_and_index_for_children!(node)
    for i in eachindex(node.children)
        node.children[i].parent = node
        node.children[i].index = i
    end
end

# Adjust the depth field of node and all its recursive children by
# delta.
function adjust_depth!(node, delta)
    next_node = move_right_no_descent(node)
    node′ = node
    while node′ !== next_node
        node′.depth += delta
        node′ = move_right(node′)
    end
end

function get_column(node)
    node.column_is_current || update_columns!(node)
    @assert node.column_is_current
    return node.column
end

# Update column numbers for the whole row.
function update_columns!(node)
    # First move left until we find a current column or the start of
    # the row.
    while !node.column_is_current
        node′ = move_left(node)
        if is_root(node′) || contains_newline(node′)
            break
        end
        node = node′
    end

    # Determine the column of node.
    if node.column_is_current
        column = node.column
    else
        left = move_left(node)
        if is_root(node)
            column = 1
        else
            column = 1 + length(last(rsplit(left.text, "\n", limit = 2)))
        end
        node.column = column
        node.column_is_current = true
    end

    # Update column until the end of the row.
    while true
        contains_newline(node) && break
        if is_leaf(node)
            column += length(node.text)
        end
        node = move_right(node)
        is_root(node) && break
        node.column = column
        node.column_is_current = true
    end

    # Verify that column values are good or not current for the whole
    # tree. This can be very slow on large files and is only intended
    # to be activated for debugging or occasional sanity checking.
    if false
        while !is_root(node)
            node = node.parent
        end
        column = 1
        while true
            if node.column_is_current && node.column != column
                error("Bad column.")
            end
            if is_leaf(node)
                text = node.text
                if contains(text, "\n")
                    column = 1 + length(last(rsplit(text, "\n", limit = 2)))
                else
                    column += length(text)
                end
            end
            node = move_right(node)
            is_root(node) && break
        end
    end
end

function invalidate_column_for_rest_of_row(node, column = node.column)
    while true
        node = move_right(node)
        node.column_is_current || break
        node.column_is_current = false
        if is_root(node) || contains_newline(node)
            break
        end
    end
end

function contains_newline(node::Node)
    return node.newline_index > 0
end
