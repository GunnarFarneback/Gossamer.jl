debug = false

function indent(node)
    # Special case, trim space from the very start of the file
    if node.row == 1 && get_column(node) == 1 && iskind(node, K"Whitespace")
        reference_text = node.text
        node.text = lstrip(node.text, (' ', '\t'))
        if node.text != reference_text
            invalidate_column_for_rest_of_row(node)
        end
        return 0
    end

    # Also trim space from the very end of the file.
    if iskind(node, K"Whitespace") && is_root(move_right(node))
        node.text = rstrip(node.text, (' ', '\t'))
    end

    # Otherwise, only consider newline nodes.
    iskind(node, K"NewlineWs") || return 0

    parent = node.parent
    index = node.index

    @assert count(==('\n'), node.text) == 1

    debug && println("--------------------------------------------------------")
    # Search left, including descending into subexpressions, for the
    # previous newline. This is only used to determine whether
    # unrelated indentations have the same depth and need to be
    # separated by an empty line.
    previous_newline_node = nothing
    previous_newline_in_reference_path = false
    node′ = node
    while !is_root(node′)
        node′ = move_left(node′)
        if iskind(node′, K"NewlineWs")
            previous_newline_node = node′
            break
        end
    end

    # Search left, without descending into subexpressions, for the
    # relevant previous newline. Count enclosing blocks. Take notice
    # if we see the previous newline in this search.
    num_block_indents = 0
    num_hanging_block_indents = 0
    base_indent = 0
    reference_newline_node = nothing
    in_module = false
    in_first_let_block = false
    in_second_let_block = iskind(node.parent, K"let")
    block_construction_found = false
    dedent_follows = false
    if iskind(move_right(node), K"end", K"else", K"elseif",
              K"catch", K"finally")
        num_block_indents -= 1
        num_hanging_block_indents -= 1
        dedent_follows = true
    end
    node′ = node
    while !is_root(node′)
        if is_leaf(node′) && iskind(node′, K"begin", K"while", K"for", K"if",
                                    K"let", K"function", K"module", K"do",
                                    K"try", K"quote", K"struct", K"macro")
            block_construction_found = true
            # 'let' has a somewhat different representation with two
            # blocks.
            if iskind(node′.parent.parent, K"let")
                if iskind(move_left(node′.parent), K"let")
                    in_first_let_block = true
                else
                    in_second_let_block = true
                    node′ = node′.parent
                end
            elseif iskind(node′, K"for") && iskind(move_right(node′), K"filter")
            else
                num_block_indents += 1
            end
        end
        node′ = move_left_no_descent(node′)
        if is_leaf(node′) && iskind(node′, K"module")
            in_module = true
            num_block_indents -= 1
        elseif (is_leaf(node′) && iskind(node′, K")")
                && iskind(node′.parent, K"call", K"dotcall"))
            while !iskind(node′, K"(")
                node′ = move_left_no_descent_to_leaf(node′)
            end
        elseif iskind(node′, K"NewlineWs")
            if node′ === previous_newline_node
                previous_newline_in_reference_path = true
            end
            # Don't let comment only lines trip us up. Specifically we
            # don't reindent first column comments so need to search
            # past them. Likewise skip whitespace only lines, which
            # should normally be empty.
            if !is_next_line_not_indented(node′)
                reference_newline_node = node′
                base_indent = indentation_of_node(node′)
                break
            end
        elseif !is_leaf(node′)
            if first(node′.children) === previous_newline_node
                previous_newline_in_reference_path = true
            end
            if !iskind(node′, K"block") && !(iskind(node′, K"tuple")
                                             && iskind(node′.parent, K"do"))
                # Sometimes the relevant newline is the first child of a
                # node rather than preceding it.
                first_child = first(node′.children)
                if (first_child !== node && iskind(first_child, K"NewlineWs")
                    && !is_next_line_not_indented(first_child))

                    reference_newline_node = first_child
                    base_indent = indentation_of_node(first_child)
                    break
                end
            end
        end
    end
    reference_row_number = isnothing(reference_newline_node) ?
                           1 : reference_newline_node.row + 1
    debug && @show (base_indent, num_block_indents) reference_row_number

    # Search left without descending into subexpressions to identify
    # an opening node for a hanging indent. Count enclosing blocks up
    # to the opening node.
    opening_node = nothing
    opening_column = -1
    colon_column = -1
    ternary_column = -1
    opening_is_import_like = false
    node′ = node
    while !is_root(node′)
        if iskind(node′.parent, K"block") && is_first_sibling(node′)
            if !iskind(node′.parent.parent, K"let")
                num_hanging_block_indents += 1
            end
        end
        node′ = move_left_no_descent(node′)
        if !is_leaf(node′) && iskind(node′, K"do")
            # Ascend, to avoid finding the function call parentheses
            # in the `do` function call, which would confuse us.
            node′ = node′.parent
        end
        if is_leaf(node′) && (iskind(node′, K"(", K"[", K"{", K"let")
                              || iskind(node′, K"=", K"import", K"using",
                                        K"export", K"public", K"return"))
            opening_node = node′
            opening_column = (get_column(opening_node) + length(node′.text)
                              + iskind(node′, K"let", K"import", K"using",
                                       K"export", K"public", K"return"))
            debug && @show get_column(opening_node) length(node′.text)
            if iskind(node′, K"import", K"using", K"export", K"public",
                      K"return")
                opening_is_import_like = true
            end
            break
        elseif (iskind(node′.parent, K"iteration") &&
                iskind(move_left(node′.parent), K"for"))
            opening_node = move_left(node′.parent)
            opening_column = get_column(node′.parent) + 1
            break
        elseif (iskind(node′.parent, K"iteration") &&
                iskind(node′.parent.parent, K"filter") &&
                iskind(move_left(node′.parent.parent), K"for"))
            opening_node = move_left(node′.parent.parent)
            opening_column = get_column(node′.parent.parent) + 1
            break
        elseif is_leaf(node′) && iskind(node′, K":")
            colon_column = get_column(node′) + 1
        elseif is_leaf(node′) && iskind(node′, K"?")
            ternary_column = get_column(node′) + 1
        end
    end
    debug && @show num_hanging_block_indents

    in_incomplete_expression = false
    if !isnothing(previous_newline_node) && has_attribute(previous_newline_node, :in_incomplete_expression)
        in_incomplete_expression = true
    else
        node′ = move_left_no_descent_to_leaf(node)
        if (node_is_operator(node′) || opening_is_import_like
            || (!isnothing(opening_node) && iskind(opening_node, K"for")))

            if move_right_to_leaf(node′) === node
                in_incomplete_expression = true
            end
        end
    end
    if (in_incomplete_expression
        && is_next_line_not_indented(node))

        add_attribute!(node, :in_incomplete_expression)
    end
    debug && @show in_incomplete_expression

    # Look right for `end` or a closing delimiter.
    node′ = move_right_to_leaf(node)
    next_is_closing = false
    while iskind(node′, K"Comment")
        node′ = move_right_to_leaf(node′)
    end
    if iskind(node′, K")", K"]", K"}")
        next_is_closing = true
    end

    debug && @show num_block_indents
    indent_to = Int[]
    prefer_hanging_indent = false
    # Hanging indent.
    node′ = node
    while iskind(node′, K"NewlineWs")
        node′ = move_left_no_descent_to_leaf(node′)
    end
    if !isnothing(opening_node) && (opening_node.row == node′.row
                                    || opening_node.row == reference_row_number
                                    || next_is_closing)
        hanging_indent = (opening_column + node_is_operator(opening_node) - 1
                          + 4 * num_hanging_block_indents)
        debug && @show kind(opening_node) opening_column hanging_indent
        push!(indent_to, hanging_indent)
        next_node = move_right_to_leaf(opening_node)
        debug && @show in_incomplete_expression reference_newline_node
        if (in_incomplete_expression
            && opening_node === move_left_no_descent_to_leaf(node))

        elseif next_node === node || (iskind(opening_node, K"(")
                                      && iskind(next_node, K";")
                                      && move_right(next_node) === node)
            # Opening delimiter immediately followed by newline.
            if !block_construction_found
                num_block_indents += 1
            end
        elseif (!iskind(next_node, K"NewlineWs")
                && !(iskind(opening_node, K"(") && iskind(next_node, K";")
                     && iskind(move_right(next_node), K"NewlineWs")))
            # Opening delimiter followed by something substantial.
            if opening_node.row >= reference_row_number || next_is_closing
                prefer_hanging_indent = true
                if !block_construction_found && !dedent_follows
                    num_block_indents += 1
                end
            end
        end
        if opening_is_import_like && colon_column >= 0
            pushfirst!(indent_to, colon_column)
        end
    end

    if (ternary_column >= 0 && iskind(move_left(node), K":")
        && iskind(node.parent, K"?"))

        pushfirst!(indent_to, ternary_column)
    end

    extra_indent_from_continued_operator = false
    if in_incomplete_expression
        if !has_attribute(reference_newline_node, :continued_operator)
            if !block_construction_found
                num_block_indents += 1
                extra_indent_from_continued_operator = true
            end
        end
        add_attribute!(node, :continued_operator)
    end

    if in_second_let_block
        prefer_hanging_indent = false
    end

    # Indentation without consideration of hanging indent.
    left_indent = base_indent + 4 * num_block_indents
    debug && @show prefer_hanging_indent left_indent base_indent num_block_indents
    if prefer_hanging_indent
        if !in_first_let_block
            push!(indent_to, left_indent)
        end
    else
        pushfirst!(indent_to, left_indent)
        if next_is_closing
            pushfirst!(indent_to, left_indent - 4)
        end
    end
    if in_module
        push!(indent_to, base_indent + 4 * (num_block_indents + 1))
    end
    if !isnothing(opening_node) && extra_indent_from_continued_operator
        push!(indent_to, left_indent - 4)
    end

    debug && @show indent_to

    # Get rid of negative indentations. Shouldn't be here but if they
    # turn up we prefer a questionable indentation over an error.
    indent_to .= max.(indent_to, 0)

    # Remove trailing space and convert indenting tabs to spaces.
    exotic_spaces = preprocess_indentation_space!(node)
    reference_text = node.text

    old_indent = indentation_of_node(node)
    debug && @show old_indent
    if isempty(indent_to) || old_indent in indent_to
        set_attribute!(node, :nominal_indent, old_indent)
    else
        set_attribute!(node, :nominal_indent, first(indent_to))
        # Do not indent lines starting with `#` in the first column.
        # Do not indent multiline strings or commands.
        if !is_not_indented_comment(move_right(node)) &&
            !is_multiline_string_or_cmd(move_right(node))

            node.text = string("\n", " "^first(indent_to))
            node.text *= exotic_spaces
            if node.text != reference_text
                invalidate_column_for_rest_of_row(node)
            end
        end
    end

    # If this newline was preceded by a whitespace only line, now is
    # the time to trim that line.
    prev_node = move_left_to_leaf(node)

    if iskind(prev_node, K"NewlineWs")
        reference_text = prev_node.text
        prev_node.text = "\n" * lstrip(prev_node.text, (' ', '\n', '\t'))
        if prev_node.text != reference_text
            invalidate_column_for_rest_of_row(prev_node)
        end
    elseif true
        # Otherwise, check whether the current indentation is the same
        # as the indentation on the last line. If it is and those
        # indentations are unrelated, separate the lines with an empty
        # line. Well, unless the current line is already empty.
        p = previous_newline_node
        debug && @show node p
        if !isnothing(p) && !previous_newline_in_reference_path &&
            !iskind(move_right_to_leaf(node), K"NewlineWs") &&
            !is_root(move_right(node)) &&
            indentation_of_node(p) == indentation_of_node(node)

            # Additionally only add a line if this is at the start of
            # a block and the block is not empty.
            if ((iskind(move_left(node), K"block")
                 || iskind(move_right(node), K"block"))
                && length(node.parent.children) > 1)

                prev = move_left_to_leaf(node)
                if !(iskind(prev, K"end", K")", K"]", K"}")
                     && is_first_on_line(prev))

                    debug && @show "inserting!"
                    insert_leaf_node!(node.parent, node.index, K"NewlineWs", "\n")
                    return 1
                end
            end
        end
    end

    return 0
end

# Is node first on its line, whitespace excluded?
function is_first_on_line(node)
    node′ = move_left(node)
    if iskind(node′, K"Whitespace")
        node′ = move_left(node′)
    end
    return is_root(node′) || iskind(node′, K"NewlineWs")
end

function indentation_of_node(node)
    @assert iskind(node, K"NewlineWs")
    if has_attribute(node, :nominal_indent)
        return get_attribute(node, :nominal_indent)
    end
    node′ = move_right(node)
    # At the very end of the tree this takes us to the root.
    if is_root(node′)
        return length(node.text[findfirst(==('\n'), node.text):end])
    end

    return get_column(node′) - 1
end

# We don't indent comments if they start in the first column or span
# multiple lines.
function is_not_indented_comment(node)
    iskind(node, K"Comment") || return false
    get_column(node) == 1 && return true
    contains(node.text, "\n") && return true
    return false
end

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

# Determine whether a NewlineWs node starts a line not subject to
# indentation.
#
# This includes:
# * Empty lines.
# * Lines with only whitespace.
# * Lines with a comment starting in the first column.
# * Lines starting (whitespace excluded) with a comment spanning
#   multiple lines.
function is_next_line_not_indented(node)
    @assert iskind(node, K"NewlineWs")
    node′ = move_right(node)
    while node′.row == node.row + 1
        if !iskind(node′, K"NewlineWs") && !is_not_indented_comment(node′)
            return false
        end
        node′ = move_right(node′)
    end
    return true
end

# * Remove all space before newline, i.e. trailing space, and update
#   `node.text`.
# * Skip normal space (space, tab) after newline until an exotic space
#   (e.g. nonbreaking space) is found.
#   * Tabs found during skipping are converted to space.
# * Return the remaining space.
function preprocess_indentation_space!(node)
    reference_text = node.text
    newline_index = findfirst(==('\n'), node.text)
    node.text = node.text[newline_index:end]
    num_tabs_to_replace = 0
    exotic_spaces = ""
    for index in eachindex(node.text)
        c = node.text[index]
        if c == '\t'
            num_tabs_to_replace += 1
        elseif c != '\n' && c != ' '
            exotic_spaces = node.text[index:end]
            break
        end
    end
    if num_tabs_to_replace > 0
        node.text = replace(node.text, '\t' => ' ';
                            count = num_tabs_to_replace)
    end
    if node.text != reference_text
        invalidate_column_for_rest_of_row(node)
    end
    return exotic_spaces
end
