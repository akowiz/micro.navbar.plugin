--- @module navbar.lang

local nvb_path = "navbar/?.lua;"
if not string.find(package.path, nvb_path) then
    package.path = nvb_path .. package.path
end

local lg = {}


local gen  = require('generic')
local tree = require('tree')


lg.T_NONE       = 0
lg.T_OBJECT     = 1
lg.T_CLASS      = 2
lg.T_FUNCTION   = 3
lg.T_VARIABLE   = 4
lg.T_CONSTANT   = 5

local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Convert lg.T_XXX into human readeable string.
-- @tparam int kind One of T_NONE, T_CLASS, T_FUNCTION or T_CONSTANT.
-- @treturn string The human readable type.
function lg.kind_to_str(kind)
    local ret = 'None'
    if kind == lg.T_OBJECT then
        ret = 'Object'
    elseif kind == lg.T_CLASS then
        ret = 'Class'
    elseif kind == lg.T_FUNCTION then
        ret = 'Function'
    elseif kind == lg.T_VARIABLE then
        ret = 'Variable'
    elseif kind == lg.T_CONSTANT then
        ret = 'Constant'
    end
    return ret
end

--- Convert a tree (made of Nodes) into a list of TreeLine (used to display our navbar).
-- @tparam Node tree The tree to convert.
-- @treturn table A list of TreeLine.
function lg.tree_to_navbar(tree, stylename, spacing)
    stylename = stylename or 'bare'
    spacing = spacing or 0

    local tl_list = tree:list_tree(stylename, spacing)

    return tl_list
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- Node inherit from tree.NodeSimple.
-- @type Node
lg.Node = gen.class(tree.NodeSimple)

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
-- @tparam bool closed Whether this node should be closed or not (i.e. whether children will be visible or not).
function lg.Node:__init(name, kind, line)
    tree.NodeSimple.__init(self, name)
    self.kind = kind or lg.T_NONE
    self.line = line or -1
end

--- Indicates how to order nodes.
-- @tparam Node node The node to be compared to the current node.
-- @treturn bool true if the current node is 'before' the node.
function lg.Node:__lt(node)
    -- Allow us to sort the nodes by kind, and then by name
    return (self.kind < node.kind) or ((self.kind == node.kind) and (self.name < node.name))
end

--- Return a representation of the current node.
-- Note: the order doesn't match the Node() constructor, but it is easier to read.
-- @treturn string Node(kind, name, line, indend).
function lg.Node:__repr()
    -- Allow us to display the nodes in a readable way.
    return 'Node(' .. table.concat({self.kind, self.name, self.line}, ', ') .. ')'
end

--- Add a children to the current node.
-- Both the current node and the child will be modified: Child will be added to
-- current node's children and current node will be set as the parent of the
-- child.
-- @tparam Node child The node to be added as a children of the current node.
function lg.Node:append(node)
    if DEBUG then
        local kind = lg.kind_to_str(node.kind)
        print(kind .. ' ' .. tostring(node) .. ' added to ' .. tostring(self))
    end
    tree.NodeBase.append(self, node)
end

--- Recursively build a tree representation of the current node (node as root) as a list.
-- The table tree is used to accumulate the result of the recursion.
-- @tparam table style A style table to be used to display items.
-- @tparam Node node The node to process.
-- @tparam table list A table used to store all strings generated.
-- @tparam string padding The string to use as padding for the current node.
-- @tparam bool islast Set to true if node is the last children.
-- @tparam bool isfirst Set to true if node is the first children.
local function list_rec(style, node, list, padding, islast, isfirst)
    style = style or tree.get_style('bare', 0)
    list = list or {}
    padding = padding or ''

    local lead

    -- print(node.name, padding, islast, isfirst)

    if     islast then
        lead = node:select_lead(style['lst_key'],
                                style['lst_key_open'])
    elseif isfirst then
        lead = node:select_lead(style['1st_level_1st_key'],
                                style['1st_level_1st_key_open'])
    else
        lead = node:select_lead(style['nth_key'],
                                style['nth_key_open'])
    end

    table.insert(list, {
        text = padding .. lead .. node:get_label(),
        node = node,
    })

    for k, child in ipairs(node:get_children()) do
        local child_first = (k == 1)
        local child_last = (k == #node:get_children())
        local child_padding
        if islast then
            child_padding = padding .. style['empty']
        else
            child_padding = padding .. style['link']
        end
        list_rec(style, child, list, child_padding, child_last, child_first)
    end
end

--- Build a tree representation of the current node (node as root).
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam bool hide_me Set to true to 'hide' the current node (i.e. only display its' children)
-- @treturn table A list of {display_text, line}.
function lg.Node:list(stylename, spacing, hide_me)
    -- Returns the tree (current node as root) in a string.
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false

    local style = tree.get_style(stylename, spacing)
    local list = {}
    local lead = nil
    local padding = nil

    if not hide_me then
        padding = style['empty']

        lead = self:select_lead(style['root'],
                                style['root_open'])
        table.insert(list, {
            text = lead .. self:get_label(),
            node = self,
        })
    end

    local children = self:get_children()
    for k, child in ipairs(children) do
        local isfirst = (k == 1)
        local islast  = (k == #children)
        list_rec(style, child, list, padding, islast, isfirst)
    end

    return list
end



--- Recursively build a tree representation of the current node as a list of TreeLine.
-- The table tree is used to accumulate the result of the recursion.
-- @tparam table style A style table to be used to display items.
-- @tparam Node node The node to process.
-- @tparam table list A table used to store all TreeLine objects generated.
-- @tparam string padding The string to use as padding for the current node.
-- @tparam bool islast Set to true if node is the last children.
-- @tparam bool isfirst Set to true if node is the first children.
local function list_tree_rec(style, node, list, padding, islast, isfirst)
    style = style or tree.get_style('bare', 0)
    list = list or {}
    padding = padding or ''

    local lead_type

    -- print(node.name, padding, islast, isfirst)

    if     islast then
        lead_type = node:select_lead('lst_key', 'lst_key_open')
    elseif isfirst then
        lead_type = node:select_lead('1st_level_1st_key', '1st_level_1st_key_open')
    else
        lead_type = node:select_lead('nth_key', 'nth_key_open')
    end

    table.insert(list, tree.TreeLine(node, padding, lead_type, style))

    for k, child in ipairs(node:get_children()) do
        local child_first = (k == 1)
        local child_last = (k == #node:get_children())
        local child_padding
        if islast then
            child_padding = padding .. style['empty']
        else
            child_padding = padding .. style['link']
        end
        list_tree_rec(style, child, list, child_padding, child_last, child_first)
    end
end

--- Build a tree representation of the current node (node as root).
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam bool hide_me Set to true to 'hide' the current node (i.e. only display its' children)
-- @treturn table A list of TreeLine() objects.
function lg.Node:list_tree(stylename, spacing, hide_me)
    -- Returns the tree (current node as root) in a string.
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false

    local style = tree.get_style(stylename, spacing)
    local list = {}
    local lead_type = nil
    local padding = nil

    if not hide_me then
        lead_type = self:select_lead('root', 'root_open')
        table.insert(list, tree.TreeLine(self, '', lead_type, style))
        padding = style['empty']
    end

    local children = self:get_children()
    for k, child in ipairs(children) do
        local isfirst = (k == 1)
        local islast  = (k == #children)
        list_tree_rec(style, child, list, padding, islast, isfirst)
    end

    return list
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lg
