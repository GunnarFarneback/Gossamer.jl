debug = !false

mutable struct IndentState
    opening_node::Node
    opening_is_substantial::Bool
    ternary_node::Node
    colon_node::Node
    hanging_indents::Int
    num_block_indents::Int
    conditional_block_indent::Bool
    num_hanging_block_indents::Int
    base_indent::Int
    reference_newline_node::Node
    in_module::Bool
    in_first_let_block::Bool
    in_second_let_block::Bool
    block_construction_found::Bool
    dedent_follows::Bool
    dedent_closing_parenthesis::Bool
    in_incomplete_expression::Bool
    extra_indent_from_continued_expression::Bool

    # TODO: Once the code is sufficiently stable, replace this with a
    # standard constructor of the actual fields.
    function IndentState(root::Node)
        state = new()
        for i in 1:fieldcount(IndentState)
            name = fieldname(IndentState, i)
            type = fieldtype(IndentState, i)
            if type === Node
                setfield!(state, name, root)
            elseif type <: Vector
                setfield!(state, name, type())
            else
                setfield!(state, name, zero(type))
            end
        end
        return state
    end
end

# TODO: Once the code is sufficiently stable, replace this with a
# direct copy of the actual fields.
function copy_state!(to::IndentState, from::IndentState)
    for i in 1:fieldcount(IndentState)
        name = fieldname(IndentState, i)
        type = fieldtype(IndentState, i)
        if type <: Vector
            #value = getfield(from, name)
            #resize!(getfield(to, name), length(value)) .= value
            empty!(getfield(to, name))
        else
            setfield!(to, name, getfield(from, name))
        end
    end
end

# TODO: Once the code is sufficiently stable, replace the macro with
# its expansion in the code.
macro s(x)
    esc(:(states[node.depth].$x))
end

# JuliaSyntax is not entirely helpful with the placement of newline
# nodes.
#
# 1. A newline as the final sibling, especially of a block, is better
#    moved up a level in the tree.
# 2. A newline preceding a non-leaf node, especially a block, is
#    better moved into the non-leaf node.
#
# TODO: Make this happen immediately after or at construction of the
# tree. For now we do it later in order not to break the old
# indentation code.
#
# TODO: Update name and comment since this now handles more than
# newlines.
function move_newlines!(root::Node)
    node = rightmost_leaf(root)
    while !is_root(node)
        parent = node.parent
        if iskind(node, K"NewlineWs") && !is_root(parent)
            if is_last_sibling(node)
                # Newline as last sibling, move it out to parent.
                move_last_sibling_out_of_node!(node)
                continue
            elseif is_first_sibling(node) && iskind(parent, K"call", K"importpath", K"as", K"=")
                move_first_sibling_out_of_node!(node)
                continue
            else
                next = move_right(node)
                if !is_leaf(next) && !is_root(next) && iskind(next, K"block")
                    move_node_into_following_sibling!(node)
                    continue
                end
            end
        elseif iskind(node, K"begin") && iskind(parent, K"block") && is_first_sibling(node)
            move_first_sibling_out_of_node!(node)
            continue
        elseif iskind(node, K"end") && iskind(parent, K"block") && is_last_sibling(node)
            move_last_sibling_out_of_node!(node)
            #continue
        elseif !is_leaf(node) && iskind(node, K"do") && iskind(node.parent, K"call") && iskind(move_left(node), K")") && is_last_sibling(node)
            restructure_do!(node)
        end
        node = move_left(node)
    end
end

# JuliaSyntax representation of `do` constructions is
# unnecessarily difficult for formatting to work with.
# Slightly simplified it has the structure
#
#   [call]
#     Identifier
#     (
#     ...
#     )
#     [do]
#       do
#       [tuple]
#       [block]
#
# We would rather prefer it be
#
#   [do]
#     [call]
#     do
#     [tuple]
#     [block]
#
# This function implements that transformation.
function restructure_do!(node)
    node1 = node.parent
    node2 = node
    # Step 1, switch the kinds of the call and do nodes:
    #
    #   [do]
    #     Identifier
    #     (
    #     ...
    #     )
    #     [call]
    #       do
    #       [tuple]
    #       [block]
    #
    node1.head, node2.head = node2.head, node1.head
    # Step 2, move the current [call] children up to the parent:
    #
    #   [do]
    #     Identifier
    #     (
    #     ...
    #     )
    #     [call]
    #     do
    #     [tuple]
    #     [block]
    append!(node1.children, node2.children)
    empty!(node2.children)
    # Step 3, move the nodes preceding [call] into [call]:
    #
    #   [do]
    #     [call]
    #       Identifier
    #       (
    #       ...
    #       )
    #     do
    #     [tuple]
    #     [block]
    while first(node1.children) !== node2
        push!(node2.children, popfirst!(node1.children))
    end
    # Step 4, fix the tree internal consistency.
    refresh_parent_and_index_for_children!(node1)
    refresh_parent_and_index_for_children!(node2)
    adjust_depth!.(node2.children, 1)
    adjust_depth!.(@view(node1.children[2:end]), -1)
end

function format_indent!(root::Node, max_depth::Int)
    move_newlines!(root)
    states = [IndentState(root) for _ in 1:max_depth]
    previous_newline_node = root

    node = move_right(root)

    # Trim space from the very start of the file.
    if iskind(node, K"Whitespace")
        reference_text = node.text
        node.text = lstrip(node.text, (' ', '\t'))
        if node.text != reference_text
            invalidate_column_for_rest_of_row(node)
        end
    end

    while !is_root(node)
        # Do not indent inside multiline strings or commands.
        if iskind(node, K"string", K"cmdstring")
            node = move_right_no_descent(node)
            continue
        end

        debug && println("  ", node.row, " ", node.column, " ", kind(node))
        if !is_leaf(node)
        else
            if iskind(node, K"(", K"[", K"{", K"=", K"import", K"using",
                      K"export", K"public", K"return")
                println("Found opening ", _string(node), " at depth ", node.depth)
                @s(opening_node) = node
                @s(num_hanging_block_indents) = 0
                _is_opening_substantial = is_opening_substantial(node)
                @show _is_opening_substantial
                @s(opening_is_substantial), indent_block =
                    _is_opening_substantial
                if iskind(node, K"=")
                    if !@s(extra_indent_from_continued_expression)
                        @s(conditional_block_indent) = true
                    end
                else
                    @s(num_block_indents) += indent_block
                end
            elseif iskind(node, K":")
                @s(colon_node) = node
            elseif iskind(node, K"?")
                @s(ternary_node) = node
            elseif iskind(node, K"NewlineWs")
                indent_newline_node!(root, node, states, previous_newline_node)
                previous_newline_node = node
            end
        end

        # Colons are handled separately with colon_node etc.
        if node_is_operator(node) && !iskind(node, K":")
            @s(in_incomplete_expression) = true
        elseif !iskind(node, K"Whitespace", K"NewlineWs") && is_leaf(node)
            @s(in_incomplete_expression) = false
        end

        depth = node.depth
        node = move_right(node)
        if node.depth > depth
            @assert node.depth == depth + 1
            copy_state!(states[depth + 1], states[depth])
            @s(in_module) = false
            @s(dedent_closing_parenthesis) = false
            if !@s(in_incomplete_expression)
                @s(extra_indent_from_continued_expression) = false
            end
            @s(in_incomplete_expression) = false

            if iskind(node.parent, K"block")
                if true
                    @show "incrementing num_hanging_block_indents at depth $(node.depth)"
                    @s(num_block_indents) += 1
                    @s(num_hanging_block_indents) += 1
                end
                if iskind(node.parent.parent, K"module")
                    @s(in_module) = true
                end
                if iskind(node.parent.parent, K"let") && iskind(move_left(node.parent), K"let")
                    println("Found let opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(opening_is_substantial) = true
                end
            elseif iskind(node.parent, K"iteration")
                if iskind(node.parent.parent, K"for", K"generator") && iskind(move_left(node.parent), K"for")
                    println("Found for opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(num_block_indents) += 1
                    @s(opening_is_substantial) = true
                elseif iskind(node.parent.parent, K"filter") && iskind(move_left(node.parent.parent), K"for")
                    println("Found for opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(num_block_indents) += 1
                    @s(opening_is_substantial) = true
                end
            end

        end
    end

    # Also trim space from the very end of the file.
    node = rightmost_leaf(root)
    if iskind(node, K"Whitespace")
        node.text = rstrip(node.text, (' ', '\t'))
    end
end

# Perform the actual reindentation.
function indent_newline_node!(root, node, states, previous_newline_node)
    debug && println("--------------------------------------------------------")

    opening_node = @s(opening_node)
    opening_is_substantial = @s(opening_is_substantial)
    reference_newline_node = @s(reference_newline_node)
    block_construction_found = @s(block_construction_found)
    dedent_follows = @s(dedent_follows)
    num_block_indents = @s(num_block_indents)
    conditional_block_indent = @s(conditional_block_indent)
    num_hanging_block_indents = @s(num_hanging_block_indents)
    ternary_node = @s(ternary_node)
    colon_node = @s(colon_node)
    in_first_let_block = @s(in_first_let_block)
    in_second_let_block = @s(in_second_let_block)
    base_indent = @s(base_indent)
    in_module = @s(in_module)
    dedent_closing_parenthesis = @s(dedent_closing_parenthesis)

    # Do not indent lines starting with `#` in the first column.
    # Do not indent multiline strings or commands.
    if is_not_indented_comment(move_right(node)) ||
        is_multiline_string_or_cmd(move_right(node))

        return
    end

    # If whitespace only line, strip it down and leave the indentation
    # state unchanged.
    if iskind(move_right(node), K"NewlineWs")
        # TODO: This is likely somewhat oversimplified.
        node.text = "\n"
        return
    end

    opening_column = -1
    if !is_root(opening_node)
        opening_column = (get_column(opening_node) + length(opening_node.text)
                          + iskind(opening_node, K"let", K"import", K"using",
                                   K"export", K"public", K"return", K"for"))
    end

    hanging_indent = -1
    secondary_hanging_indent = -1
    prefer_hanging_indent = false
    if !is_root(opening_node)
        @show opening_column num_hanging_block_indents
        hanging_indent = (opening_column + node_is_operator(opening_node) - 1
                          + 4 * num_hanging_block_indents)
        prefer_hanging_indent = opening_is_substantial
        if !is_root(colon_node) && iskind(opening_node, K"import", K"using")
            secondary_hanging_indent = hanging_indent
            hanging_indent = get_column(colon_node) + 1
            prefer_hanging_indent = !iskind(move_right(colon_node),
                                            K"NewlineWs")
        elseif !is_root(ternary_node)
            secondary_hanging_indent = hanging_indent
            hanging_indent = get_column(ternary_node) + 1
            prefer_hanging_indent = !iskind(move_right(ternary_node),
                                            K"NewlineWs")
        end
    elseif !is_root(colon_node) && iskind(colon_node.parent.parent, K"import", K"using")
        hanging_indent = get_column(colon_node) + 1
        colon_is_substantial = !iskind(move_right(colon_node), K"NewlineWs")
        prefer_hanging_indent = colon_is_substantial
        num_block_indents += !colon_is_substantial
    elseif !is_root(ternary_node)
        hanging_indent = get_column(ternary_node) + 1
        ternary_is_substantial = !iskind(move_right(ternary_node), K"NewlineWs")
        prefer_hanging_indent = ternary_is_substantial
        num_block_indents += !ternary_is_substantial
    end

    # Indentation without consideration of hanging indent.
    if conditional_block_indent
        num_block_indents = max(1, num_block_indents)
    end
    left_indent = base_indent + 4 * num_block_indents
    secondary_left_indent = -1

    @show @s(in_incomplete_expression) @s(extra_indent_from_continued_expression)
    if @s(in_incomplete_expression) && !@s(extra_indent_from_continued_expression)
        if num_block_indents == 0
            secondary_left_indent = left_indent
            left_indent += 4
        end
        @s(extra_indent_from_continued_expression) = true
    end

    base_indent_offset = 0
    # TODO: Replace looking left by use of a state variable.
    if iskind(move_left(node), K"function", K"macro")
        left_indent += 4
        base_indent_offset = -4
    end

    #if is_root(opening_node) && iskind(move_right(node), K")", K"]", K"}")
    if dedent_closing_parenthesis && iskind(move_right(node), K")", K"]", K"}")
        secondary_left_indent = left_indent
        left_indent -= 4
    elseif in_module
        secondary_left_indent = left_indent
        left_indent -= 4
    end

    # Remove trailing space and convert indenting tabs to spaces.
    exotic_spaces = preprocess_indentation_space!(node)
    reference_text = node.text
    old_indent = indentation_of_node(node)

    if old_indent == hanging_indent || old_indent == left_indent || old_indent == secondary_hanging_indent || old_indent == secondary_left_indent
        indent_to = old_indent
    elseif prefer_hanging_indent
        indent_to = hanging_indent
    else
        indent_to = left_indent
    end

    debug && @show base_indent old_indent _string(opening_node) opening_is_substantial prefer_hanging_indent num_block_indents conditional_block_indent indent_to in_module
    debug && @show (hanging_indent, left_indent, secondary_hanging_indent, secondary_left_indent)

    if indent_to != hanging_indent != -1
        @show "Left indenting, updating state."
        @s(dedent_closing_parenthesis) = true
        if iskind(node.parent, K"parameters")
            states[node.parent.depth].dedent_closing_parenthesis = true
        end
        depth = node.depth
        while depth >= 1 && states[depth].num_block_indents > 0
            @show depth
            states[depth].opening_node = root
            states[depth].num_hanging_block_indents = 0
            states[depth].opening_is_substantial = false
            states[depth].dedent_closing_parenthesis = true
            depth -= 1
        end
    else
    end
    @s(base_indent) = indent_to + base_indent_offset
    @s(num_block_indents) = 0
    if @s(conditional_block_indent)
        depth = node.depth
        while depth >= 1 && states[depth].conditional_block_indent
            states[depth].conditional_block_indent = false
            depth -= 1
        end
    end
    @s(opening_node) = root
    @s(opening_is_substantial) = false
    @s(colon_node) = root

    node.text = string("\n", " "^indent_to)
    node.text *= exotic_spaces
    if node.text != reference_text
        invalidate_column_for_rest_of_row(node)
    end

    # Check whether the current indentation is the same as the
    # indentation on the last line. If it is and those indentations
    # are unrelated, separate the lines with an empty line. Don't do
    # this for empty blocks or when the previous line is a closing
    # character or end.
    if !is_root(previous_newline_node) && iskind(move_left(node), K"block") && !is_leaf(move_left(node)) && indent_to == indentation_of_node(previous_newline_node)
        prev = move_right(previous_newline_node)
        if !(iskind(prev, K"end", K")", K"]", K"}"))
            insert_leaf_node!(node.parent, node.index, K"NewlineWs", "\n")
        end
    end
    #=
    # If this newline was preceded by a whitespace only line, now is
    # the time to trim that line.
    prev_node = move_left_to_leaf(node)

    if iskind(prev_node, K"NewlineWs")
        reference_text = prev_node.text
        prev_node.text = "\n" * lstrip(prev_node.text, (' ', '\n', '\t'))
        if prev_node.text != reference_text
            invalidate_column_for_rest_of_row(prev_node)
        end
    elseif false
        # TODO: Update this code

        # Otherwise, check whether the current indentation is the same
        # as the indentation on the last line. If it is and those
        # indentations are unrelated, separate the lines with an empty
        # line. Well, unless the current line is already empty.
        p = previous_newline_node
        debug && @show node p
        if !is_root(p) && !previous_newline_in_reference_path &&
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
                    return
                end
            end
        end
    end
    =#
end

# Check whether an opening node is substantial, i.e. that it is not
# immediately followed by a newline. For assignments certain operators
# also count as insubstantial.
function is_opening_substantial(node)
    @show _string(node)
    node′ = move_right_to_leaf(node)
    if iskind(node′, K"Whitespace")
        node′ = move_right(node′)
    end
    if iskind(node, K"(") && iskind(node′, K";")
        node′ = move_right_to_leaf(node′)
    end
    @show _string(node′)
    iskind(node′, K"NewlineWs") && return false, !node_is_operator(node)
    iskind(node′, K"begin", K"while", K"for", K"if",
           K"let", K"try", K"quote") && return false, true
    iskind(node′, K"call", K"vect") && return true, true
    return true, true
end

function indent(node)
    # Special case, trim space from the very start of the file
    if node.row == 1 && get_column(node) == 1 && iskind(node, K"Whitespace")
        reference_text = node.text
        node.text = lstrip(node.text, (' ', '\t'))
        if node.text != reference_text
            invalidate_column_for_rest_of_row(node)
        end
        return
    end

    # Also trim space from the very end of the file.
    if iskind(node, K"Whitespace") && is_root(move_right(node))
        node.text = rstrip(node.text, (' ', '\t'))
    end

    # Otherwise, only consider newline nodes.
    iskind(node, K"NewlineWs") || return

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

    opening_node = get_attribute(node, :opening, nothing)
    opening_is_import_like = false
    opening_column = -1
    if !isnothing(opening_node)
        opening_is_import_like = iskind(opening_node, K"import", K"using",
                                        K"export", K"public", K"return")
        opening_column = (get_column(opening_node) + length(opening_node.text)
                          + iskind(opening_node, K"let", K"import", K"using",
                                   K"export", K"public", K"return", K"for"))
    end
    colon_column = -1
    if has_attribute(node, :colon)
        colon_column = get_column(get_attribute(node, :colon)) + 1
    end
    ternary_column = -1
    if has_attribute(node, :ternary)
        ternary_column = get_column(get_attribute(node, :ternary)) + 1
    end

    num_hanging_block_indents += get_attribute(node, :hanging_indents, 0)
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

    # Hanging indent.
    prefer_hanging_indent = false
    if !isnothing(opening_node)
        node′ = node
        while iskind(node′, K"NewlineWs")
            node′ = move_left_no_descent_to_leaf(node′)
        end

        if (opening_node.row == node′.row
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
                    # if !iskind(opening_node, K"=") || !iskind(node′, K"begin", K"if", K"elseif", K"else", K"let", K"do", K"try", K"catch", K"finally")
                    if true
                        prefer_hanging_indent = true
                    end
                    if !block_construction_found && !dedent_follows
                        num_block_indents += 1
                    end
                end
            end
            if opening_is_import_like && colon_column >= 0
                pushfirst!(indent_to, colon_column)
            end
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
                    return
                end
            end
        end
    end

    return
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
    node′ = move_right_to_leaf(node)
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
