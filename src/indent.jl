debug = false

mutable struct IndentState
    opening_node::Node
    opening_is_substantial::Bool
    ternary_node::Node
    colon_node::Node
    num_block_indents::Int
    conditional_block_indent::Bool
    num_hanging_block_indents::Int
    base_indent::Int
    in_module::Bool
    dedent_closing_parenthesis::Bool
    in_incomplete_expression::Bool
    extra_indent_from_continued_expression::Bool
    disable_left_indent::Bool

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
        if iskind(node, K"NewlineWs", K"Comment", K"Whitespace") && !is_root(parent)
            if is_last_sibling(node) && iskind(node, K"NewlineWs")
                # Newline as last sibling, move it out to parent.
                move_last_sibling_out_of_node!(node)
                continue
            elseif is_first_sibling(node) && (iskind(parent, K"call", K"dotcall", K"importpath", K"as", K"=", K"function") || node_is_operator(parent, false))
                # Might be multiple newlines to move out, so we may
                # need to backtrack.
                next = move_right(node)
                move_first_sibling_out_of_node!(node)
                node = next
                continue
            elseif !is_last_sibling(node)
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
        elseif !is_leaf(node) && iskind(node, K"do") && iskind(node.parent, K"call", K"dotcall") && iskind(move_left(node), K")") && is_last_sibling(node)
            restructure_do!(node)
        elseif !is_leaf(node) && iskind(node, K"if", K"elseif", K"while") && iskind(first(node.children), K"if", K"elseif", K"while")
            restructure_if_and_while!(node)
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

# JuliaSyntax representation of `if` and `while` constructions are not
# ideal for formatting to work with.
# Simplified they have the structure
#
#   [if]
#     if
#     ...
#     [block]
#     end
#
# where `...` are all nodes involved in the condition.
#
# We would rather prefer to have it structured like
#
#   [if]
#     if
#     [condition]
#       ...
#     [block]
#     end
#
# with the condition nodes collected in an umbrella node. However,
# there is no `condition` kind in JuliaSyntax, so we borrow the
# `wrapper` kind instead.
#
# `while` is structured the same as `if` and is transformed
# identically. The `if` case does become somewhat more complicated in
# the presence of `elseif` and `else` but in practice that has only
# minor impact on the transformation. However, `elseif` in turn needs
# the same transformation as `if`. (That does not require recursion;
# this function is just called on both the `if` and `elseif` nodes.)
function restructure_if_and_while!(node)
    # Step 1, find the last `block` node, not immediately following an
    # `else`. (There can be additional `block` nodes in the condition
    # and one more block after `else`).
    #
    #   [if]
    #     if
    #     ...
    #     [block]   * this *
    #     end
    final_block_index = -1
    for i in length(node.children):-1:2
        if iskind(node.children[i], K"block") && !iskind(node.children[i - 1], K"else")
            final_block_index = i
            break
        end
    end

    if final_block_index < 2
        # This shouldn't happen, but if it does we just skip the
        # transformation.
        return
    end
    final_block_node = node.children[final_block_index]

    # Step 2, insert an empty wrapper node as second child.
    #
    #   [if]
    #     if
    #     [wrapper]
    #     ...
    #     [block]
    #     end
    wrapper = Node(Node[], 2, 0, 0, "", SyntaxHead(K"wrapper", 0x0000), node)
    insert!(node.children, 2, wrapper)
    wrapper.is_leaf = false

    # Step 3, move the condition nodes into the wrapper node.
    #
    #
    #   [if]
    #     if
    #     [wrapper]
    #       ...
    #     [block]
    #     end
    while node.children[3] !== final_block_node
        push!(wrapper.children, popat!(node.children, 3))
    end

    # Step 4, fix the tree internal consistency.
    refresh_parent_and_index_for_children!(node)
    refresh_parent_and_index_for_children!(wrapper)
    adjust_depth!.(wrapper.children, 1)
end

function format_indent!(root::Node)
    states = [IndentState(root) for _ in 1:max_tree_depth(root)]
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

        debug && println(_string(node))
        if !is_leaf(node)
        else
            if iskind(node, K"(", K"[", K"{", K"=", K"import", K"using",
                      K"export", K"public", K"return")
                debug && println("Found opening ", _string(node), " at depth ", node.depth)
                @s(opening_node) = node
                @s(num_hanging_block_indents) = 0
                _is_opening_substantial = is_opening_substantial(node)
                debug && @show _is_opening_substantial
                @s(opening_is_substantial), indent_block =
                    _is_opening_substantial
                if iskind(node, K"=", K"return")
                    if !@s(extra_indent_from_continued_expression)
                        @s(conditional_block_indent) = true
                    end
                else
                    @s(num_block_indents) += indent_block
                end
            elseif iskind(node, K":")
                @s(colon_node) = node
            elseif iskind(node, K"?")
                if !iskind(move_left(node), K"NewlineWs")
                    @s(ternary_node) = node
                end
            elseif iskind(node, K"NewlineWs")
                indent_newline_node!(root, node, states, previous_newline_node)
                previous_newline_node = node
            end
        end

        # Colons are handled separately with colon_node etc.
        if (node_is_operator(node) || is_comma_in_bare_tuple(node)) && !iskind(node, K":") && iskind(move_right_to_leaf(node), K"NewlineWs")
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
            @s(disable_left_indent) = false
            @s(dedent_closing_parenthesis) = false
            if !@s(in_incomplete_expression)
                @s(extra_indent_from_continued_expression) = false
            end
            @s(ternary_node) = root

            if iskind(node.parent, K"block")
                if true
                    debug && @show "incrementing num_hanging_block_indents at depth $(node.depth)"
                    @s(num_block_indents) += 1
                    @s(num_hanging_block_indents) += 1
                end
                if iskind(node.parent.parent, K"module")
                    @s(in_module) = true
                end
                if iskind(node.parent.parent, K"let") && iskind(move_left(node.parent), K"let")
                    debug && println("Found let opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(opening_is_substantial) = true
                end
            elseif iskind(node.parent, K"iteration")
                if iskind(node.parent.parent, K"for", K"generator") && iskind(move_left(node.parent), K"for")
                    debug && println("Found for opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(num_block_indents) += 1
                    @s(opening_is_substantial) = true
                elseif iskind(node.parent.parent, K"filter") && iskind(move_left(node.parent.parent), K"for")
                    debug && println("Found for opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(num_block_indents) += 1
                    @s(opening_is_substantial) = true
                end
            elseif iskind(node.parent, K"wrapper")
                # Notes: K"wrapper" is a kind that we have inserted
                # into the tree ourselves. We don't bother to check
                # that we have matching if/while nodes below, because
                # JuliaSyntax wouldn't create that and even if it did,
                # it wouldn't necessarily affect the formatting.
                if iskind(node.parent.parent, K"if", K"elseif", K"while") && iskind(move_left(node.parent), K"if", K"elseif", K"while")
                    debug && println("Found if/while opening ", _string(node.parent.parent), " at depth ", node.depth)
                    @s(opening_node) = move_left(node.parent)
                    @s(num_hanging_block_indents) = 0
                    @s(num_block_indents) += 1
                    @s(opening_is_substantial) = false
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

function max_tree_depth(root)
    # Determine maximum tree depth.
    max_depth = 0
    node = root
    while true
        node = move_right(node)
        is_root(node) && break
        max_depth = max(max_depth, node.depth)
    end
    return max_depth
end

# Perform the actual reindentation.
function indent_newline_node!(root, node, states, previous_newline_node)
    debug && println("--------------------------------------------------------")

    opening_node = @s(opening_node)
    opening_is_substantial = @s(opening_is_substantial)
    num_block_indents = @s(num_block_indents)
    conditional_block_indent = @s(conditional_block_indent)
    num_hanging_block_indents = @s(num_hanging_block_indents)
    ternary_node = @s(ternary_node)
    colon_node = @s(colon_node)
    base_indent = @s(base_indent)
    in_module = @s(in_module)
    dedent_closing_parenthesis = @s(dedent_closing_parenthesis)
    disable_left_indent = @s(disable_left_indent)

    # Do not indent lines starting with `#` in the first column.
    # Do not indent multiline strings or commands.
    if is_not_indented_comment(move_right(node)) ||
        is_multiline_string_or_cmd(move_right(node))

        node.text = lstrip(node.text, (' ', '\t'))
        return
    end

    # Split the NewlineWs text into three parts:
    # 1. Text before the newline.
    # 2. Newline character(s), either \n or \r\n.
    # 3. Text after the newline
    #
    # TODO: after_newline is never used but related to exotic_spaces.
    before_newline, after_newline = split(node.text, "\n", limit = 2)
    newline_chars = "\n"
    if endswith(before_newline, "\r")
        before_newline = chopsuffix(before_newline, "\r")
        newline_chars = "\r\n"
    end

    # If whitespace only line, strip it down and leave the indentation
    # state unchanged.
    if iskind(move_right(node), K"NewlineWs")
        node.text = lstrip(before_newline, (' ', '\t')) * newline_chars
        return
    end

    opening_column = -1
    if !is_root(opening_node)
        opening_column = (get_column(opening_node) + length(opening_node.text)
                          + iskind(opening_node, K"let", K"import", K"using",
                                   K"export", K"public", K"return", K"for",
                                   K"if", K"elseif", K"while"))
    end

    if iskind(node.parent, K"?") && is_root(ternary_node)
        num_hanging_block_indents += 1
    end

    hanging_indent = -1
    secondary_hanging_indent = -1
    tertiary_hanging_indent = -1
    prefer_hanging_indent = false
    if !is_root(opening_node)
        debug && @show opening_column num_hanging_block_indents _string(ternary_node)
        hanging_indent = (opening_column + node_is_operator(opening_node) - 1
                          + 4 * num_hanging_block_indents)
        prefer_hanging_indent = opening_is_substantial
        if !is_root(colon_node) && iskind(opening_node, K"import", K"using")
            secondary_hanging_indent = hanging_indent
            hanging_indent = get_column(colon_node) + 1
            prefer_hanging_indent = !iskind(move_right(colon_node),
                                            K"NewlineWs")
        elseif !is_root(ternary_node)
            ternary_column = get_column(ternary_node) + 1
            node′ = leftmost_leaf(ternary_node.parent)
            if iskind(node′, K"NewlineWs", K"Whitespace", K"Comment")
                node′ = move_right_to_leaf(node′)
            end
            ternary_start_column = get_column(node′) - 1
            if iskind(move_right(node), K"?") && node.parent === ternary_node.parent
                # A new ternary inside a ternary.
                tertiary_hanging_indent = hanging_indent
                secondary_hanging_indent = ternary_column
                hanging_indent = ternary_start_column
            elseif iskind(move_right(node), K":") && node.parent === ternary_node.parent
                # Ternary colon at start of a line
                tertiary_hanging_indent = hanging_indent
                secondary_hanging_indent = ternary_start_column
                hanging_indent = get_column(ternary_node) - 1
            else
                tertiary_hanging_indent = hanging_indent
                secondary_hanging_indent = ternary_start_column
                hanging_indent = ternary_column
            end
            prefer_hanging_indent = !iskind(move_right(ternary_node),
                                            K"NewlineWs")
        elseif @s(in_incomplete_expression) && !@s(extra_indent_from_continued_expression)
            secondary_hanging_indent = hanging_indent + 4
        end
    elseif !is_root(colon_node) && iskind(colon_node.parent.parent, K"import", K"using")
        hanging_indent = get_column(colon_node) + 1
        colon_is_substantial = !iskind(move_right(colon_node), K"NewlineWs")
        prefer_hanging_indent = colon_is_substantial
        num_block_indents += !colon_is_substantial
    elseif !is_root(ternary_node)
        # TODO: Refactor this with the previous ternary code for
        # hanging indents.
        ternary_column = get_column(ternary_node) + 1
        node′ = leftmost_leaf(ternary_node.parent)
        while iskind(node′, K"NewlineWs", K"Whitespace", K"Comment")
            node′ = move_right_to_leaf(node′)
        end
        ternary_start_column = get_column(node′) - 1
        if iskind(move_right(node), K"?") && node.parent === ternary_node.parent
            # A new ternary inside a ternary.
            tertiary_hanging_indent = hanging_indent
            secondary_hanging_indent = ternary_column
            hanging_indent = ternary_start_column
        elseif iskind(move_right(node), K":") && node.parent === ternary_node.parent
            # Ternary colon at start of a line
            tertiary_hanging_indent = hanging_indent
            secondary_hanging_indent = ternary_start_column
            hanging_indent = get_column(ternary_node) - 1
        else
            tertiary_hanging_indent = hanging_indent
            secondary_hanging_indent = ternary_start_column
            hanging_indent = ternary_column
        end

        ternary_is_substantial = !iskind(move_right(ternary_node), K"NewlineWs")
        prefer_hanging_indent = ternary_is_substantial
        num_block_indents += !ternary_is_substantial && is_root(colon_node)
    end

    # Indentation without consideration of hanging indent.
    if conditional_block_indent
        num_block_indents = max(1, num_block_indents)
    end

    if disable_left_indent && hanging_indent == -1
        disable_left_indent = false
    end

    left_indent = -1
    secondary_left_indent = -1
    if !disable_left_indent
        left_indent = base_indent + 4 * num_block_indents
        if num_block_indents > 1
            secondary_left_indent = base_indent + 4
        end
    end

    debug && @show @s(in_incomplete_expression) @s(extra_indent_from_continued_expression)
    if @s(in_incomplete_expression) && !@s(extra_indent_from_continued_expression)
        if num_block_indents == 0 && !disable_left_indent
            secondary_left_indent = left_indent
            left_indent += 4
        end
        @s(extra_indent_from_continued_expression) = true
    end

    base_indent_offset = 0
    # TODO: Replace looking left by use of a state variable.
    if iskind(move_left(node), K"function", K"macro") && !disable_left_indent
        left_indent += 4
        base_indent_offset = -4
    end

    if !disable_left_indent
        if dedent_closing_parenthesis && iskind(move_right(node), K")", K"]", K"}") && left_indent >= 4
            secondary_left_indent = left_indent
            left_indent -= 4
        elseif in_module
            secondary_left_indent = left_indent
            left_indent -= 4
            @s(in_module) = false
        end
    end

    # Remove trailing space and convert indenting tabs to spaces. Move
    # exotic space into the text of the following leaf node.
    exotic_spaces = preprocess_indentation_space!(node)
    if !isempty(exotic_spaces)
        node′ = move_right_to_leaf(node)
        node′.text = exotic_spaces * node′.text
        invalidate_column_for_rest_of_row(node′)
    end
    reference_text = node.text
    old_indent = indentation_of_node(node)

    if old_indent == hanging_indent || old_indent == left_indent || old_indent == secondary_hanging_indent || old_indent == secondary_left_indent || old_indent == tertiary_hanging_indent
        indent_to = old_indent
    elseif prefer_hanging_indent
        indent_to = hanging_indent
    else
        indent_to = left_indent
    end

    debug && @show base_indent old_indent _string(opening_node) opening_is_substantial prefer_hanging_indent num_block_indents conditional_block_indent indent_to in_module
    if debug
        indent_options = (hanging_indent, left_indent, secondary_hanging_indent, secondary_left_indent, tertiary_hanging_indent)
        @show indent_options
    end

    if (indent_to != hanging_indent != -1) && indent_to != secondary_hanging_indent && indent_to != tertiary_hanging_indent
        # Choosing left indentation although hanging indentation is
        # preferred. Keep doing that going forward.
        debug && @show "Left indenting, updating state."
        @s(dedent_closing_parenthesis) = true
        if iskind(node.parent, K"parameters")
            states[node.parent.depth].dedent_closing_parenthesis = true
        end
        depth = node.depth
        while depth >= 1 && states[depth].num_block_indents > 0
            debug && @show depth
            states[depth].opening_node = root
            states[depth].num_hanging_block_indents = 0
            states[depth].opening_is_substantial = false
            states[depth].dedent_closing_parenthesis = true
            depth -= 1
        end

        if num_block_indents > 1 && indent_to == secondary_left_indent
            # Choosing to underindent left indent.
            depth = node.depth
            while depth >= 1 && states[depth].num_block_indents > 0
                debug && @show depth
                states[depth].num_block_indents = 0
                depth -= 1
            end
        end
    elseif !prefer_hanging_indent && hanging_indent != -1 && indent_to != left_indent && indent_to != secondary_left_indent && !is_root(opening_node)
        # Choosing hanging indent despite not being preferred. Keep
        # doing that going forward.
        @s(opening_is_substantial) = true
        depth = node.depth - 1
        while depth >= 1 && states[depth].opening_node === states[node.depth].opening_node
            debug && @show depth
            states[depth].opening_is_substantial = true
            states[depth].disable_left_indent = true
            depth -= 1
            states[depth + 1].num_block_indents > 0 || break
        end
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

    @assert indent_to >= 0
    node.text = string(newline_chars, " "^indent_to)
    if node.text != reference_text
        invalidate_column_for_rest_of_row(node)
    end

    # Check whether the current indentation is the same as the
    # indentation on the last line. If it is and those indentations
    # are unrelated, separate the lines with an empty line. Don't do
    # this for empty blocks or when the previous line is a closing
    # character or end.
    if !is_root(previous_newline_node) && iskind(move_left(node), K"block") && !is_leaf(move_left(node)) && !iskind(move_left(node).parent, K"module", K"baremodule") && indent_to == indentation_of_node(previous_newline_node)
        prev = move_right(previous_newline_node)
        if !(iskind(prev, K"end", K")", K"]", K"}"))
            insert_leaf_node!(node.parent, node.index, K"NewlineWs", newline_chars)
        end
    end

    # The ternary indentation is more future context sensitive than
    # other indentation and might get out of sync with preceding
    # comments. If that is the case, traverse backwards to adjust
    # those indentations.
    if !is_root(ternary_node)
        node′ = move_left(node)
        while iskind(node′, K"Comment")
            node′′ = node′
            node′ = move_left(node′)
            iskind(node′, K"NewlineWs") || break
            indentation_of_node(node′) == indent_to && break
            if !is_not_indented_comment(node′′)
                reference_text = node′.text
                newline_chars = contains(node′.text, "\r\n") ? "\r\n" : "\n"
                node′.text = string(newline_chars, " "^indent_to)
                if node′.text != reference_text
                    invalidate_column_for_rest_of_row(node′)
                end
            end
            node′ = move_left(node′)
        end
    end
end

function is_comma_in_bare_tuple(node)
    iskind(node, K",") || return false
    iskind(node.parent, K"tuple") || return false
    return !iskind(first(node.parent.children), K"(")
end

# Check whether an opening node is substantial, i.e. that it is not
# immediately followed by a newline. For assignments certain operators
# also count as insubstantial.
function is_opening_substantial(node)
    node′ = move_right_to_leaf(node)
    if iskind(node′, K"Whitespace")
        node′ = move_right(node′)
    end
    if iskind(node, K"(") && iskind(node′, K";")
        node′ = move_right_to_leaf(node′)
    end
    iskind(node′, K"NewlineWs") && return false, !node_is_operator(node)
    iskind(node′, K"begin", K"while", K"for", K"if", K"elseif",
           K"let", K"try", K"quote", K"do") && return false, true
    iskind(node′, K"call", K"dotcall", K"vect") && return true, true
    return true, true
end

# Is node first on its line, whitespace excluded?
function is_first_on_line(node)
    node′ = move_left(node)
    if iskind(node′, K"Whitespace")
        node′ = move_left(node′)
    end
    return is_root(node′) || iskind(node′, K"NewlineWs")
end

# TODO: Revise \n vs \r\n. Do we need the end of tree case?
function indentation_of_node(node)
    @assert iskind(node, K"NewlineWs")
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
#
# TODO: Can this be combined with the before_newline, newline_chars,
#       after_newline split?
function preprocess_indentation_space!(node)
    reference_text = node.text
    newline_index = findfirst(==('\n'), node.text)
    if newline_index > 1
        prev_index = prevind(node.text, newline_index)
        if node.text[prev_index] == '\r'
            newline_index = prev_index
        end
    end
    node.text = node.text[newline_index:end]
    num_tabs_to_replace = 0
    exotic_spaces = ""
    for index in eachindex(node.text)
        c = node.text[index]
        if c == '\t'
            num_tabs_to_replace += 1
        elseif c != '\n' && c != ' ' && (c != '\r' || index > 1)
            exotic_spaces = node.text[index:end]
            node.text = node.text[1:prevind(node.text, index)]
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
