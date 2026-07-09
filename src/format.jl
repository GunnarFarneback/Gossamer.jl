function format_string(s::AbstractString)
    node = parse_string(s)
    format_node!(node)
    return write_node(node)
end

# This is written with an explicit stack instead of recursion to be
# able to handle pathological code. However, it turns out that
# JuliaSyntax fails in its recursion for deeply nested code, so for
# now we don't get to handle such cases here.
function format_node!(node::Node, parent::Node = node)
    stack = [(node, 1)]
    while !isempty(stack)
        node, i = pop!(stack)
        inhibit_node_recursion(node) && continue
        propagate_inline_space_inhibition(node)
        i > length(node.children) && continue
        child = node.children[i]
        space_after_comma(child)
        i = space_around_binary_operator(child)
        space_after_comment(child)
        i += indent(child)
        push!(stack, (node, i + 1))
        push!(stack, (child, 1))
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
    if iskind(node, K",", K";")
        if !(is_whitespace(next) || iskind(next, K")", K"]", K"}", K",", K";") || iskind(prev, K"(", K"[", K"{"))
            if node.index > 1 && iskind(prev, K"Whitespace")
                # Swap ` ,` to `, `.
                node.head, prev.head = prev.head, node.head
                node.text, prev.text = prev.text, node.text
                node.column_is_current = false
                prev.column_is_current = false
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
    space_node_before = nothing
    nonspace_before = false
    dot_before = false
    op_before = false
    for i in (index - 1):-1:1
        sibling = parent.children[i]
        if iskind(sibling, K"Whitespace", K"NewlineWs")
            space_before = true
            space_node_before = sibling
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
    space_node_after = nothing
    nonspace_after = false
    equals_after = false
    comma_after = false
    op_after = false
    closing_after = false
    if !is_last_sibling(node)
        node′ = move_right_to_leaf(node)
        directly_after = true
        while true
            if directly_after && iskind(node′, K"=")
                equals_after = true
            elseif directly_after && node_is_operator(node′)
                op_after = true
            elseif iskind(node′, K"Whitespace", K"NewlineWs")
                space_after = true
                space_node_after = node′
            elseif iskind(node′, K",", K";", K"parameters")
                comma_after = true
            elseif iskind(node′, K")", K"]", K"}")
                closing_after = true
            else
                nonspace_after = true
                break
            end
            is_last_sibling(node′) && break
            node′ = move_right_to_leaf(node′)
            directly_after = false
        end
    end

    (nonspace_before && nonspace_after) || return index
    (comma_after || closing_after) && return index
    # Process .op when we get to op.
    iskind(node, K".") && op_after && return index

    node.text in ("^", "::", "//", "<:") && !space_before && !space_after && return index

    if node.text == "::" && space_before && !space_after
        # Accept this inside struct definitions. It occurs in the
        # wild.
        if iskind(node.parent, K"::") && iskind(node.parent.parent, K"block") && iskind(node.parent.parent.parent, K"struct")
            return index
        end
    end

    # Accept division without space if both arguments are literals.
    if node.text == "/" && !space_before && !space_after
        if is_literal(move_left(node)) && is_literal(move_right(node))
            return index
        end
    end

    next = move_right(node)
    if (iskind(node, K"=") && iskind(node.parent, K"=")
        && iskind(node.parent.parent, K"call", K"dotcall", K"parameters", K"macrocall", K"tuple")
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
    elseif node.text in ("^", "::", "//")
        if !space_before || !space_after
            if space_before
                remove_space_before = true
            end
            if space_after
                remove_space_after = true
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
    remove_space_after && remove_space!(space_node_after)
    if add_space_before
        insert_space!(parent, index - dot_before)
        index += 1
    end

    if remove_space_before
        remove_space!(space_node_before)
        index -= 1
    end

    return index
end

function space_after_comment(node)
    iskind(node, K"Comment") || return
    reference_text = node.text
    next = move_right(node)
    if is_root(next) || iskind(next, K"NewlineWs")
        node.text = rstrip(node.text, (' ', '\t'))
    end
    if contains(node.text, "\n")
        node.text = join((rstrip(line, (' ', '\t'))
                          for line in eachsplit(node.text, '\n')),
                         '\n')
    end
    if node.text != reference_text
        invalidate_column_for_rest_of_row(node)
    end
end

function insert_space!(node, index)
    insert_leaf_node!(node, index, K"Whitespace", " ")
    return
end

function remove_space!(node)
    # The code probably looks weird with a linebreak after an operator
    # that shouldn't have a space, but we don't remove linebreaks, so
    # just leave it. (Trailing space on a line is handled elsewhere.)
    iskind(node, K"NewlineWs") && return
    @assert iskind(node, K"Whitespace")
    remove_child!(node.parent, node.index)
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
