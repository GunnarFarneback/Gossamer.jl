function format_string(s::AbstractString)
    node = parse_string("", s)
    format_node!(node)
    return write_node(node)
end

function format_node!(node::Node, parent::Node = node)
    i = 1
    inhibit_node_recursion(node) && return
    propagate_inline_space_inhibition(node)
    while i <= length(node.children)
        child = node.children[i]
        space_after_comma(child)
        i = space_around_binary_operator(child)
        i += indent(child)
        format_node!(child, node)
        i += 1
    end
    return
end

# TODO: Replace with :inhibit_inline_space_formatting mechanism?
function inhibit_node_recursion(node)
    iskind(node, K"string", K"cmdstring") && return true
    is_colon_call(node) && return true
    return false
end

function is_colon_call(node)
    iskind(node, K"call") || return false
    return any(iskind(child, K"Identifier") && child.text == ":"
               for child in node.children)
end

function propagate_inline_space_inhibition(node)
    has_attribute(node, :inhibit_inline_space_formatting) || return
    for child in node.children
        add_attribute!(child, :inhibit_inline_space_formatting)
    end
end

function space_after_comma(node)
    has_attribute(node, :inhibit_inline_space_formatting) && return
    prev = move_left_to_leaf(node)
    next = move_right_to_leaf(node)
    if (iskind(node, K",", K";") &&
        iskind(node.parent, K"call", K"tuple", K"parameters", K"braces",
               K"vect", K"ref", K"curly"))

        if !(is_whitespace(next) || iskind(next, K")") || iskind(prev, K"("))
            if node.index > 1 && iskind(prev, K"Whitespace")
                # Swap ` ,` to `, `.
                node.head, prev.head = prev.head, node.head
                node.text, prev.text = prev.text, node.text
            else
                insert_space!(node.parent, node.index + 1)
            end
        end
    end
    return
end

# Returns new index of the node.
#
# TODO: Rewrite to return index offset instead of new index.
function space_around_binary_operator(node)
    parent = node.parent
    index = node.index
    index == 1 && return index
    has_attribute(node, :inhibit_inline_space_formatting) && return index
    # Only consider operator nodes.
    node_is_operator(node) || return index
    iskind(node, K".") && return index

    space_before = false
    nonspace_before = false
    dot_before = false
    op_before = false
    for i in (index - 1):-1:1
        sibling = parent.children[i]
        if iskind(sibling, K"Whitespace", K"NewlineWs")
            space_before = true
        elseif i == index - 1 && iskind(sibling, K".") && is_leaf(sibling)
            dot_before = true
        elseif i == index - 1 && node_is_operator(sibling)
            op_before = true
        else
            nonspace_before = true
            break
        end
    end

    op_before && return index

    space_after = false
    nonspace_after = false
    equals_after = false
    comma_after = false
    op_after = false
    closing_after = false
    for i in (index + 1):length(parent.children)
        sibling = parent.children[i]
        if i == index + 1 && iskind(sibling, K"=")
            equals_after = true
        elseif i == index + 1 && node_is_operator(sibling)
            op_after = true
        elseif iskind(sibling, K"Whitespace", K"NewlineWs")
            space_after = true
        elseif iskind(sibling, K",", K";", K"parameters")
            comma_after = true
        elseif iskind(sibling, K")", K"]", K"}")
            closing_after = true
        else
            if node_starts_with_whitespace(parent.children[i])
                space_after = true
            end
            nonspace_after = true
            break
        end
    end

    (nonspace_before && nonspace_after) || return index
    (comma_after || closing_after) && return index
    # Process .op when we get to op.
    iskind(node, K".") && op_after && return index

    # TODO: Remove space if unbalanced.
    node.text in ("^", "::", "//") && !space_before && !space_after && return index

    next = move_right(node)
    if (iskind(node, K"=") && iskind(node.parent, K"=")
        && iskind(node.parent.parent, K"call", K"parameters", K"macrocall", K"tuple")
        && !space_before && !space_after)

        add_attribute!(move_right(node), :inhibit_inline_space_formatting)
        return index
    end

    add_space_before = false
    add_space_after = false
    remove_space_before = false
    remove_space_after = false

    if iskind(node, K":")
        if iskind(node.parent, K":")
            # Colon in using/import.
            if !space_after
                add_space_after = true
            end
        end
    elseif node.text == ":"
        if space_before || space_after
            if !space_before
                add_space_before = true
            end
            if !space_after
                add_space_after = true
            end
        end
    else
        if !space_before
            add_space_before = true
        end

        if !space_after
            add_space_after = true
        end
    end

    @assert !(add_space_before && remove_space_before)
    @assert !(add_space_after && remove_space_after)

    add_space_after && insert_space!(parent, index + equals_after + 1)
    if remove_space_after
        i = index + equals_after + 1
        @assert iskind(parent.children[i], K"Whitespace")
        delete!(parent.children, i)
    end
    if add_space_before
        insert_space!(parent, index - dot_before)
        index += 1
    end

    if remove_space_before
        i = index - dot_before - 1
        @assert iskind(parent.children[i], K"Whitespace")
        delete!(parent.children, i)
        index -= 1
    end

    return index
end

function insert_space!(node, index)
    insert_leaf_node!(node, index, K"Whitespace", " ")
    return
end

const operator_strings = let
    i1 = reinterpret(UInt16, JuliaSyntax.Kind("BEGIN_OPS"))
    i2 = reinterpret(UInt16, JuliaSyntax.Kind("END_OPS"))
    Set(string(kind)
        for kind in JuliaSyntax.Kind.(i1:i2)
        if !JuliaSyntax.is_error(kind))
end

function node_is_operator(node)
    is_leaf(node) || return false
    if iskind(node, K"Identifier")
        return node.text in operator_strings
    end
    return JuliaSyntax.is_operator(kind(node))
end

# TODO: This can be simplified with newer functions in node.jl
function node_starts_with_whitespace(node)
    iskind(node, K"Whitespace", K"NewlineWs") && return true
    is_leaf(node) && return false
    return node_starts_with_whitespace(first(node.children))
end
