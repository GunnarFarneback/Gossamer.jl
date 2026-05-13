function format_string(s::AbstractString)
    node = parse_string("", s)
    format_node!(node)
    return write_node(node)
end

function format_node!(node::Node, parent::Node = node, base_indent::Int = 0)
    i = 1
    recurse_into_children = !inhibit_node_recursion(node)
    while i <= length(node.children)
        child = node.children[i]
        space_after_comma(child)
        i = space_around_binary_operator(child)
        base_indent = indent(child, base_indent)
        if recurse_into_children
            format_node!(child, node, base_indent)
        end
        i += 1
    end
    return
end

function inhibit_node_recursion(node)
    iskind(node, K"string") && return true
    is_colon_call(node) && return true
    return false
end

function is_colon_call(node)
    iskind(node, K"call") || return false
    return any(iskind(child, K"Identifier") && child.text == ":"
               for child in node.children)
end

function space_after_comma(node)
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
function space_around_binary_operator(node)
    parent = node.parent
    index = node.index
    index == 1 && return index
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
        && !space_before && !space_after
        && (is_literal(next) || iskind(next, K"Identifier")))

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

# Returns new base indent value.
function indent(node, base_indent)
    # Special case, trim space from the very start of the file
    if node.row == 1 && node.column == 1 && iskind(node, K"Whitespace")
        node.text = lstrip(node.text, ' ')
        return base_indent
    end

    parent = node.parent
    index = node.index
    if iskind(node, K"block") && !is_leaf(node)
        if (iskind(parent, K"else", K"elseif", K"catch", K"finally", K"module")
            || iskind(move_left(node), K"else", K"let"))

            return base_indent
        else
            return base_indent + 4
        end
    elseif kind(node) != K"NewlineWs"
        return base_indent
    end

    @assert count(==('\n'), node.text) == 1

    # Do not indent lines starting with `#` in the first column.
    is_first_column_comment(move_right(node)) && return base_indent

    # Do not indent multiline strings or commands.
    is_multiline_string_or_cmd(move_right(node)) && return base_indent

    indent_to = Int[]
    if iskind(parent, K"block")
        if iskind(move_right_to_leaf(node), K"end", K"elseif",
                  K"else", K"catch", K"finally")
            if !iskind(parent.parent, K"module")
                push!(indent_to, base_indent - 4)
            end
        else
            push!(indent_to, base_indent)
        end
    elseif iskind(parent, K"tuple") && iskind(parent.parent, K"do")
        push!(indent_to, base_indent + 4)
    elseif iskind(parent, K"let")
        push!(indent_to, base_indent + 4)
    else
        opening_node = node
        indentation_determined = false
        last_indent = -1
        opening_column = -1
        colon_column = -1
        hanging_indent = -1
        opening_is_import_like = false
        while !is_root(opening_node)
            opening_node = move_left_no_descent(opening_node)
            if iskind(opening_node, K"(", K"[", K"{")
                opening_column = opening_node.column
                break
            elseif is_leaf(opening_node) && iskind(opening_node, K"import", K"using", K"export", K"public")
                opening_column = opening_node.column + length(opening_node.text)
                opening_is_import_like = true
                break
            elseif is_leaf(opening_node) && iskind(opening_node, K":")
                colon_column = opening_node.column + 1
            elseif is_leaf(opening_node) && iskind(opening_node, K"=")
                opening_column = opening_node.column + 1
                break
            elseif iskind(opening_node, K"NewlineWs")
                last_indent = indentation_of_node(opening_node)
            else
                next = move_right_to_leaf(opening_node)
                if next !== node && iskind(next, K"NewlineWs")
                    last_indent = indentation_of_node(next)
                    hanging_indent = last_indent
                    break
                end
            end
        end

        if is_root(opening_node)
            push!(indent_to, base_indent)
        elseif last_indent >= 0
            if iskind(move_right(node), K")", K"]", K"}")
                pushfirst!(indent_to, base_indent)
                if hanging_indent == last_indent
                    pushfirst!(indent_to, last_indent)
                end
            else
                pushfirst!(indent_to, last_indent)
                push!(indent_to, base_indent + 4)
            end
        else
            next_node = move_right_to_leaf(opening_node)
            if iskind(next_node, K"Comment")
                next_node = move_right_to_leaf(opening_node)
            end
            if iskind(next_node, K"NewlineWs")
                if next_node === node
                    pushfirst!(indent_to, base_indent + 4)
                elseif !iskind(move_right(node), K")", K"]", K"}")
                    push!(indent_to, base_indent + 4)
                else
                    push!(indent_to, base_indent)
                end
            else
                @assert opening_column >= 0
                pushfirst!(indent_to, opening_column)
                push!(indent_to, base_indent + 4)
                if opening_is_import_like && colon_column >= 0
                    pushfirst!(indent_to, colon_column)
                end
            end
        end
    end

    original_text = node.text
    exotic_spaces = lstrip(node.text, (' ', '\n'))
    old_indent = indentation_of_node(node)
    if old_indent in indent_to
        return base_indent
    end
    isempty(indent_to) && return base_indent
    if iskind(move_right(node), K"NewlineWs")
        node.text = string("\n")
    else
        node.text = string("\n", " "^first(indent_to))
    end
    node.text *= exotic_spaces
    if node.text != original_text
        update_column_for_rest_of_row(move_right(node), first(indent_to) + 1)
    end

    return base_indent
end

function indentation_of_node(node)
    @assert iskind(node, K"NewlineWs")
    # TODO: This can be made more efficient.
    m = match(r"\w*\n( *)", node.text)
    @assert !isnothing(m)
    return length(only(m.captures))
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

is_first_column_comment(node) = node.column == 1 && iskind(node, K"Comment")

function is_multiline_string_or_cmd(node)
    if iskind(node, K"macrocall")
        length(node.children) < 2 && return false
        node = node.children[2]
    end
    is_leaf(node) && return false
    iskind(node, K"string", K"cmdstring") || return false
    node = node.children[1]
    return iskind(node, K"\"\"\"", K"```")
end
