function format_string(s::AbstractString)
    node = parse_string(s)
    format_node!(node)
    return write_node(node)
end

function format_node!(node::Node)
    # Catch corner case of empty file.
    isempty(node.children) && return

    format_spaces!(node)
    max_depth = 0
    node′ = node
    while true
        node′ = move_right(node′)
        is_root(node′)  && break
        max_depth = max(max_depth, node′.depth)
    end
    format_indent!(node, max_depth)
end

function format_spaces!(node::Node)
    node = move_right(node)
    while !is_root(node)
        if inhibit_node_recursion(node)
            node = move_right_no_descent(node)
            continue
        end
        propagate_inline_space_inhibition(node)
        space_after_comma(node)
        space_around_binary_operator(node)
        space_after_comment(node)
        space_before_do(node)
        node = move_right(node)
    end
    return
end

function format_indent_old!(node::Node)
    analyze_tree!(node)
    node = move_right(node)
    while !is_root(node)
        # TODO: Relax this to not include colon expressions.
        if inhibit_node_recursion(node)
            node = move_right_no_descent(node)
            continue
        end
        indent(node)
        node = move_right(node)
    end
    return
end

function analyze_tree!(tree::Node)
    stack = [(tree, 1, Node[], Node[], Node[], Int[])]
    while !isempty(stack)
        # println("stack:")
        # for (a,b,c) in stack
        #     println("  ", b, " (", a.row, ", ", a.column, ", ", kind(a), ")    (", c.row, ", ", c.column, ", ", kind(c), ")")
        # end
        # println("------")
        node, i, openings, colon_nodes, ternary_nodes, hanging_indents =
            pop!(stack)
        i > length(node.children) && continue
        child = node.children[i]
        # println("(", node.row, ", ", node.column, ", ", kind(node), ")    (", opening.row, ", ", opening.column, ", ", kind(opening), ")")
        if i == 1 && iskind(node, K"block") && !iskind(node.parent, K"let")
            hanging_indents = copy(hanging_indents)
            if !isempty(hanging_indents)
                hanging_indents[end] += 1
            end
        end
        if is_leaf(child)
            if iskind(child, K"NewlineWs")
                #@show child hanging_indents
                #println("Set attribute to ", kind(opening))
                if !isempty(openings)
                    set_attribute!(child, :opening, last(openings))
                end
                if !isempty(colon_nodes)
                    set_attribute!(child, :colon, last(colon_nodes))
                end
                if !isempty(ternary_nodes)
                    set_attribute!(child, :ternary, last(ternary_nodes))
                end
                if !isempty(hanging_indents)
                    set_attribute!(child, :hanging_indents, last(hanging_indents))
                end
            elseif iskind(child, K"(", K"[", K"{", K"let", K"=", K"import", K"using",
                          K"export", K"public", K"return")
                # println("Found opening")
                openings = vcat(openings, child)
                hanging_indents = vcat(hanging_indents, 0)
            elseif iskind(child, K":")
                colon_nodes = vcat(colon_nodes, child)
            elseif iskind(child, K"?")
                ternary_nodes = vcat(ternary_nodes, child)
            end
        else
            if iskind(child, K"do")
                # The preceding function call opening must be discarded
                # when descending into a `do`.
                openings = openings[1:(end - 1)]
            elseif i == 1 && iskind(node, K"iteration") && iskind(move_left(node), K"for")
                # Comprehension.
                openings = vcat(openings, move_left(node))
                hanging_indents = vcat(hanging_indents, 0)
            elseif i == 1 && iskind(node, K"iteration") && iskind(node.parent, K"filter") && iskind(move_left(node.parent), K"for")
                # Filtered comprehension.
                openings = vcat(openings, move_left(node.parent))
                hanging_indents = vcat(hanging_indents, 0)
            end
        end
        push!(stack, (node, i + 1, openings,
                      colon_nodes, ternary_nodes, hanging_indents))
        push!(stack, (child, 1, openings,
                      colon_nodes, ternary_nodes, hanging_indents))
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

function space_around_binary_operator(node)
    parent = node.parent
    index = node.index
    index == 1 && return
    has_attribute(node, :inhibit_inline_space_formatting) && return
    # Only consider operator nodes.
    node_is_operator(node) || return
    iskind(node, K".") && return

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

    op_before && return

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

    (nonspace_before && nonspace_after) || return
    (comma_after || closing_after) && return
    # Process .op when we get to op.
    iskind(node, K".") && op_after && return

    node.text in ("^", "::", "//", "<:") && !space_before && !space_after && return

    if node.text == "::" && space_before && !space_after
        # Accept this inside struct definitions. It occurs in the
        # wild.
        if iskind(node.parent, K"::") && iskind(node.parent.parent, K"block") && iskind(node.parent.parent.parent, K"struct")
            return
        end
    end

    # Accept division without space if both arguments are literals.
    if node.text == "/" && !space_before && !space_after
        if is_literal(move_left(node)) && is_literal(move_right(node))
            return
        end
    end

    next = move_right(node)
    if (iskind(node, K"=") && iskind(node.parent, K"=")
        && iskind(node.parent.parent, K"call", K"dotcall", K"parameters", K"macrocall", K"tuple")
        && !space_before && !space_after)

        add_attribute!(move_right(node), :inhibit_inline_space_formatting)
        return
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
    end

    if remove_space_before
        remove_space!(space_node_before)
    end

    return
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

function space_before_do(node)
    is_leaf(node) || return
    iskind(node, K"do") || return
    iskind(move_left(node), K"Whitespace") && return
    insert_space!(node.parent, node.index)
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
