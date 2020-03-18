#!/bin/env lua

local gen  = require('generic')


--- @module navbar.tree
local tree = {}


local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Return an array of string used to style a tree.
-- @tparam string stylename The name of the style to use (one of 'bare', 'ascii' or 'box').
-- @tparam int spacing The number of extra characters to use for the style. Default to 0.
-- @treturn table A table {key: string}
function tree.get_style(stylename, spacing)
    -- Returns an array containing the style to be used
    stylename = stylename or 'bare'
    spacing = spacing or 0

    ret = {}
    if     stylename == 'bare' then
        ret['root']         = '.'..string.rep('─', spacing)..' '
        ret['root_open']    = 'v'..string.rep('─', spacing)..' '
        ret['root_closed']  = '>'..string.rep('─', spacing)..' '
        ret['1st_level_1st_key']        = '.'..string.rep(' ', spacing)..' '
        ret['1st_level_1st_key_open']   = 'v'..string.rep(' ', spacing)..' '
        ret['1st_level_1st_key_closed'] = '>'..string.rep(' ', spacing)..' '
        ret['nth_key']        = '.'..string.rep(' ', spacing)..' '
        ret['nth_key_open']   = 'v'..string.rep(' ', spacing)..' '
        ret['nth_key_closed'] = '>'..string.rep(' ', spacing)..' '
        ret['lst_key']        = '.'..string.rep(' ', spacing)..' '
        ret['lst_key_open']   = 'v'..string.rep(' ', spacing)..' '
        ret['lst_key_closed'] = '>'..string.rep(' ', spacing)..' '
        ret['empty'] = ' '..string.rep(' ', spacing)..' '
        ret['link']  = ' '..string.rep(' ', spacing)..' '

    elseif stylename == 'ascii' then
        ret['root']         = '.'..string.rep('─', spacing)..' '
        ret['root_open']    = '-'..string.rep('─', spacing)..' '
        ret['root_closed']  = '+'..string.rep('─', spacing)..' '
        ret['1st_level_1st_key']        = '.'..string.rep(' ', spacing)..' '
        ret['1st_level_1st_key_open']   = '-'..string.rep(' ', spacing)..' '
        ret['1st_level_1st_key_closed'] = '+'..string.rep(' ', spacing)..' '
        ret['nth_key']        = '.'..string.rep(' ', spacing)..' '
        ret['nth_key_open']   = '-'..string.rep(' ', spacing)..' '
        ret['nth_key_closed'] = '+'..string.rep(' ', spacing)..' '
        ret['lst_key']        = 'L'..string.rep(' ', spacing)..' '
        ret['lst_key_open']   = '-'..string.rep(' ', spacing)..' '
        ret['lst_key_closed'] = '+'..string.rep(' ', spacing)..' '
        ret['empty'] = ' '..string.rep(' ', spacing)..' '
        ret['link']  = '|'..string.rep(' ', spacing)..' '

    elseif stylename == 'box' then
        ret['root']         = ' '..string.rep('─', spacing)..' '
        ret['root_open']    = '▾'..string.rep('─', spacing)..' '
        ret['root_closed']  = '▸'..string.rep('─', spacing)..' '
        ret['1st_level_1st_key']        = '├'..string.rep('─', spacing)..' '
        ret['1st_level_1st_key_open']   = '├'..string.rep('─', spacing)..' '
        ret['1st_level_1st_key_closed'] = '╞'..string.rep('═', spacing)..' '
        ret['nth_key']        = '├'..string.rep('─', spacing)..' '
        ret['nth_key_open']   = '├'..string.rep('─', spacing)..' '
        ret['nth_key_closed'] = '╞'..string.rep('═', spacing)..' '
        ret['lst_key']        = '└'..string.rep('─', spacing)..' '
        ret['lst_key_open']   = '└'..string.rep('─', spacing)..' '
        ret['lst_key_closed'] = '╘'..string.rep('═', spacing)..' '
        ret['empty'] = ' '..string.rep(' ', spacing)..' '
        ret['link']  = '│'..string.rep(' ', spacing)..' '

    end
    return ret
end

-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- NodeBase provides a bare implementation of a tree.
-- @type NodeBase
tree.NodeBase = gen.class()

function tree.NodeBase:__init()
    self.__parent = nil
    self.__children = {}
end

--- Indicates how to order nodes.
-- Should be overriden in the class that inherit Node.
-- @tparam Node node The node to be compared to the current node.
-- @treturn bool true if the current node is 'before' node.
function tree.NodeBase:__lt(node)
    -- Default order is the alphabetic order on label.
    return self:get_label() < node:get_label()
end

--- Return a representation of the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn string Node(...).
function tree.NodeBase:__repr()
    -- Default to Node(label).
    return 'Node(' .. self:get_label() .. ')'
end

--- Return a string to be used whenever we use tostring(self)
-- @treturn string A string representing our current node.
function tree.NodeBase:__tostring()
    return self:__repr()
end

--- Add a children to the current node.
-- Both the current node and the child will be modified: Child will be added to
-- current node's children and current node will be set as the parent of the
-- child.
-- @tparam Node child The node to be added as a children of the current node.
function tree.NodeBase:append(child)
    local children = self:get_children()
    if DEBUG then
        print(tostring(child) .. ' added to ' .. tostring(self))
    end
    child:set_parent(self)
    table.insert(children, child)
end

--- Return true if the node is closed.
-- Should be overriden in the class that inherit Node.
-- @treturn bool true if the current node it closed.
function tree.NodeBase:is_closed()
    return false
end

--- Return a table of children from the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn table A table of the children from the current node.
function tree.NodeBase:get_children()
    return self.__children
end

--- Retrieve the label of the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn string The label of the node.
function tree.NodeBase:get_label()
    -- Default label will be the address of the object.
    return tostring(self)
end

--- Return the parent of the current node.
-- @treturn Node The parent of the current node or nil if it doesn't have one.
function tree.NodeBase:get_parent()
    return self.__parent
end

--- Set the parent of the node.
-- @tparam Node node The parent of the node or nil if it doesn't have one.
function tree.NodeBase:set_parent(node)
    self.__parent = node
end

--- Select the lead characters for a node depending on the node's configuration.
-- The lead characters are displayed in from of the node's label in the tree.
-- @tparam string default Lead characters to be used if the node has no children.
-- @tparam string closed Lead characters to be used if the node has children and is closed.
-- @tparam string open Lead characters to be used if the node has children and is open.
-- @treturn string The lead characters to be used.
function tree.NodeBase:select_lead(default, closed, open)
    local lead = default
    local children = self:get_children()
    if not gen.is_empty(children) then
        if self:is_closed() then
            lead = closed
        else
            lead = open
        end
    end
    return lead
end

--- Recursively sort the children of the current node.
-- Only the order of the children in the various tables will be modified.
function tree.NodeBase:sort_children_rec()
    local children = self:get_children()
    if not gen.is_empty(children) then
        table.sort(children)
        for k, child in ipairs(children) do
            child:sort_children_rec()
        end
    end
end

--- Recursively build a tree representation of the current node (node as root).
-- The table tree is used to accumulate the result of the recursion.
-- @tparam table style A style table to be used to display items.
-- @tparam Node node The node to process.
-- @tparam table tree A table used to store all strings generated.
-- @tparam string padding The string to use as padding for the current node.
-- @tparam bool islast Set to true if node is the last children.
-- @tparam bool isfirst Set to true if node is the first children.
local function tree_rec(style, node, tree, padding, islast, isfirst)
    style = style or tree.get_style('bare', 0)
    tree = tree or {}
    padding = padding or ''

    local lead

    -- print(node.name, padding, islast, isfirst)

    if     islast then
        lead = node:select_lead(style['lst_key'],
                                style['lst_key_closed'],
                                style['lst_key_open'])
    elseif isfirst then
        lead = node:select_lead(style['1st_level_1st_key'],
                                style['1st_level_1st_key_closed'],
                                style['1st_level_1st_key_open'])
    else
        lead = node:select_lead(style['nth_key'],
                                style['nth_key_closed'],
                                style['nth_key_open'])
    end
    table.insert(tree, padding .. lead .. node:get_label())

    if not node:is_closed() then
        for k, child in ipairs(node:get_children()) do
            local child_first = (k == 1)
            local child_last = (k == #node:get_children())
            local child_padding
            if islast then
                child_padding = padding .. style['empty']
            else
                child_padding = padding .. style['link']
            end
            tree_rec(style, child, tree, child_padding, child_last, child_first)
        end
    end
end

--- Build a tree representation of the current node (node as root).
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam bool hide_me Set to true to 'hide' the current node (i.e. only display its' children)
-- @treturn string The tree in a string format.
function tree.NodeBase:tree(stylename, spacing, hide_me)
    -- Returns the tree (current node as root) in a string.
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false

    local style = tree.get_style(stylename, spacing)
    local tree = {}
    local lead = nil
    local padding = nil

    if not hide_me then
        padding = style['empty']

        lead = self:select_lead(style['root'],
                                style['root_closed'],
                                style['root_open'])
        table.insert(tree, lead .. self:get_label())
    end

    if not self:is_closed() then
        local children = self:get_children()
        for k, child in ipairs(children) do
            local isfirst = (k == 1)
            local islast  = (k == #children)
            tree_rec(style, child, tree, padding, islast, isfirst)
        end
    end

    return table.concat(tree, '\n')
end


--- NodeSimple inherit from NodeBase
-- @type NodeSimple
tree.NodeSimple = gen.class(tree.NodeBase)

--- Initialize our object.
-- @tparam string name The name of the node.
-- @tparam bool closed The status of the node, set to true to have it closed.
function tree.NodeSimple:__init(name, closed)
    tree.NodeBase.__init(self)
    self.name = name or ''
    self.closed = closed or false
end

--- Retrieve the label of the node.
-- @treturn string The label of the node.
function tree.NodeSimple:get_label()
    return tostring(self.name)
end

--- Retrieve the status of the node.
-- @treturn bool true if the node is 'closed'.
function tree.NodeSimple:is_closed()
    return self.closed
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return tree