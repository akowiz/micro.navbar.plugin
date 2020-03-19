package.path = "navbar/?.lua;" .. package.path

local gen  = require('generic')
local tree = require('tree')


--- @module navbar.lang_python
local lgp = {}


lgp.T_NONE = 0
lgp.T_CLASS = 1
lgp.T_FUNCTION = 2
lgp.T_CONSTANT = 3

local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Convert lgp.T_XXX into human readeable string.
-- @tparam int kind One of T_NONE, T_CLASS, T_FUNCTION or T_CONSTANT.
-- @treturn string The human readable type.
function lgp.kind_to_str(kind)
    local ret = 'None'
    if kind == lgp.T_CLASS then
        ret = 'Class'
    elseif kind == lgp.T_FUNCTION then
        ret = 'Function'
    elseif kind == lgp.T_CONSTANT then
        ret = 'Variable'
    end
    return ret
end

--- Test a string and attempt to extract a python item (class, function, etc.)
-- @tparam string line A line of text to analyse.
-- @treturn Node An object recording the information about the item, or nil if we identify nothing.
function lgp.match_python_item(line)
    local indent = 0
    local name
    local kind
    local ret = nil

    local found = false

    while not found do

        -- match a function
        indent, name = string.match(line, "^(%s*)def%s*([_%a%d]-)%s*%(")
        if name then
            kind = lgp.T_FUNCTION
            indent = indent:len()
            found = true
            break
        end

        -- match a class
        indent, name = string.match(line, "^(%s*)class%s*([_%a%d]-)%s*[(:]")
        if name then
            kind = lgp.T_CLASS
            indent = indent:len()
            found = true
            break
        end

        -- match a variable
        name = string.match(line, "^([_%a%d]-)%s*=[^=]")
        if name then
            kind = lgp.T_CONSTANT
            found = true
            break
        end

        break
    end

    if found then
        ret = lgp.Node(name, kind, indent)
    end

    return ret
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- Node inherit from tree.NodeSimple.
-- @type Node
lgp.Node = gen.class(tree.NodeSimple)

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
-- @tparam bool closed Whether this node should be closed or not (i.e. whether children will be visible or not).
function lgp.Node:__init(name, kind, indent, line, closed)
    tree.NodeSimple.__init(self, name, closed)
    self.kind = kind or lgp.T_NONE
    self.line = line or 0
    self.indent = indent or 0
end

--- Indicates how to order nodes.
-- @tparam Node node The node to be compared to the current node.
-- @treturn bool true if the current node is 'before' the node.
function lgp.Node:__lt(node)
    -- Allow us to sort the nodes by kind, and then by name
    return (self.kind < node.kind) or ((self.kind == node.kind) and (self.name < node.name))
end

--- Return a representation of the current node.
-- Note: the order doesn't match the Node() constructor, but it is easier to read.
-- @treturn string Node(kind, name, line, indend).
function lgp.Node:__repr()
    -- Allow us to display the nodes in a readable way.
    return 'Node(' .. table.concat({self.kind, self.name, self.line, self.indent}, ', ') .. ')'
end

--- Add a children to the current node.
-- Both the current node and the child will be modified: Child will be added to
-- current node's children and current node will be set as the parent of the
-- child.
-- @tparam Node child The node to be added as a children of the current node.
function lgp.Node:append(node)
    if DEBUG then
        local kind = lgp.kind_to_str(node.kind)
        print(kind .. ' ' .. tostring(node) .. ' added to ' .. tostring(self))
    end
    tree.NodeBase.append(self, node)
end

-------------------------------------------------------------------------------
-- Main Functions
-------------------------------------------------------------------------------

--- Export the python structure of a buffer containing python code
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgp.export_structure_python(str)
    local root = lgp.Node('/')

    local parents = {}   -- table of parents indexed by indent
    local parent = nil
    local node
    local current_indent = 0

    -- Extract structure from the buffer

    local lines = str:split('\n')
    for nb, line in ipairs(lines) do

        node = lgp.match_python_item(line)

        if node then
            if node.indent > current_indent then
                parent = parents[current_indent]
                current_indent = node.indent

            elseif node.indent < current_indent then
                if node.indent == 0 then
                    parent = root
                else
                    parent = parents[node.indent]:get_parent()
                end
                current_indent = node.indent

            else -- node.indent == current_indent then
                if node.indent == 0 then
                    parent = root
                else
                    -- do nothing special
                end
            end
            parent:append(node)
            parents[node.indent] = node
        end
    end

    root:sort_children_rec()

    return root
end

--- Convert a tree (made of Nodes) into 3 trees (made of Nodes)
-- @tparam Node tree The tree to convert.
-- @treturn table A table of trees.
function lgp.tree_to_navbar(tree)
    local ttree     = {}
    local classes   = lgp.Node('Classes')
    local functions = lgp.Node('Functions')
    local constants = lgp.Node('Variables')

    for k, v in ipairs(tree:get_children()) do
        if v.kind == lgp.T_CLASS then
            classes:append(v)
        elseif v.kind == lgp.T_FUNCTION then
            functions:append(v)
        elseif v.kind == lgp.T_CONSTANT then
            constants:append(v)
        end
    end

    ttree[lgp.T_CLASS] = classes
    ttree[lgp.T_FUNCTION] = functions
    ttree[lgp.T_CONSTANT] = constants

    return ttree
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgp
