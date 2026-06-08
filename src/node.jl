using JuliaSyntax: JuliaSyntax, parseall, GreenNode, SyntaxHead, @K_str

mutable struct Node
    # Empty for leaf nodes.
    children::Vector{Node}
    # Sibling index. Unless `node` is the root node, it must always
    # hold that `node === node.parent[node.index]`.
    index::Int
    # Row in source. Never changes, only used for debugging. Nodes
    # inserted while formatting have row number zero.
    row::Int
    # Starting column in source. Used for determining indentation.
    # Must always be kept up to date.
    column::Int
    # The source text covered by this node. For non-leaf nodes this is
    # always the original source.
    text::Union{String, SubString{String}}
    # Head of corresponding GreenNode.
    # TODO: Change to Kind?
    head::SyntaxHead
    # Formatting metadata, used as needed for bookkeeping.
    attributes::Dict{Symbol, Any}
    # Root node points to itself.
    parent::Node

    # Nodes are always created with `parent` pointing to itself
    function Node(children::Vector{Node}, index::Int, row::Int, column::Int,
                  text::Union{String, SubString{String}}, head::SyntaxHead,
                  parent::Union{Nothing, Node})
        if isnothing(parent)
            node = new(children, index, row, column, text, head,
                       Dict{Symbol, Any}())
            node.parent = node
        else
            node = new(children, index, row, column, text, head,
                       Dict{Symbol, Any}(), parent)
        end
        return node
    end
end

function Base.show(io::IO, node::Node)
    print_node(io, node, 0)
end

function print_node(io::IO, node::Node, indent)
    print(io, lpad(node.row, 5), " ")
    print(io, lpad(node.column, 5), " ")
    if isempty(node.children)
        print(io, rpad(string(" "^indent, kind(node)), 30), " ")
        if kind(node) in [K"Whitespace", K"NewlineWs"]
            print(io, "\"", escape_string(node.text), "\"")
        else
            print(io, node.text)
        end
    else
        println(io, rpad(string(" "^indent, "[", kind(node), "]"), 30), " ")
        for (i, child) in enumerate(node.children)
            print_node(io, child, indent + 1)
            i < length(node.children) && println(io)
        end
    end
end

kind(node::Node) = JuliaSyntax.kind(node.head)
iskind(node::Node, kinds::JuliaSyntax.Kind...) = any(==(kind(node)), kinds)
is_root(node) = node.parent === node
is_leaf(node) = isempty(node.children)
is_whitespace(node) = iskind(node, K"Whitespace", K"NewlineWs")
is_literal(node) = JuliaSyntax.is_literal(kind(node))
is_first_sibling(node) = first(node.parent.children) === node
is_last_sibling(node) = last(node.parent.children) === node
add_attribute!(node::Node, attr::Symbol) = set_attribute!(node, attr, true)
has_attribute(node::Node, attr::Symbol) = haskey(node.attributes, attr)
has_attribute(::Nothing, ::Symbol) = false
function set_attribute!(node::Node, attr::Symbol, value)
    node.attributes[attr] = value
end
get_attribute(node::Node, attr::Symbol) = node.attributes[attr]
get_attribute(node::Node, attr::Symbol, default) =
    get(node.attributes, attr, default)

function green_to_node(green::GreenNode, raw::AbstractString, pos::Int = 1,
                       row::Int = 1, column::Int = 1, sibling_index::Int = 1,
                       parent::Union{Nothing, Node} = nothing)
    text = raw[pos:prevind(raw, pos + green.span)]
    children = Node[]
    node = Node(children, sibling_index, row, column, text, green.head, parent)
    if !isnothing(green.children)
        for (i, green_child) in enumerate(green.children)
            child, row, column = green_to_node(green_child, raw, pos,
                                               row, column, i, node)
            push!(children, child)
            pos += green_child.span
        end
    else
        if contains(text, "\n")
            row += count(==('\n'), text)
            column = 1 + length(last(rsplit(text, "\n", limit = 2)))
        else
            column += length(text)
        end
    end
    return node, row, column
end

function parse_string(raw)
    green = parseall(GreenNode, raw; filename = "", ignore_warnings = true)
    node, _, _ = green_to_node(green, raw)
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
    leaf = Node(Node[], position, 0, 0, text, SyntaxHead(kind, 0x0000), node)
    insert!(node.children, position, leaf)
    # Leaf is in place, but we must update sibling indices and column
    # numbers for later nodes.
    for i in (position + 1):length(node.children)
        node.children[i].index = i
    end
    update_column_for_rest_of_row(move_left_to_leaf(leaf))
    return leaf
end

function remove_child!(parent, position)
    deleteat!(parent.children, position)
    # Child has been removed, but we must update sibling indices and
    # column numbers for later nodes.
    for i in position:length(parent.children)
        parent.children[i].index = i
    end
    update_column_for_rest_of_row(parent)
    return
end

function update_column_for_rest_of_row(node, column = node.column)
    while !is_root(node) && kind(node) != K"NewlineWs"
        if is_leaf(node)
            column = node.column + length(node.text)
        end
        node = move_right(node)
        node.column = column
    end
end
