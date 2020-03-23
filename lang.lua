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


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lg
