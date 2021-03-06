--- @module navbar.supported.python

local lgp = {}


local gen  = require('../generic')
local tree = require('../tree')
local lg   = require('../lang')


local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

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
            kind = lg.T_FUNCTION
            indent = indent:len()
            found = true
            break
        end

        -- match a class
        indent, name = string.match(line, "^(%s*)class%s*([_%a%d]-)%s*[(:]")
        if name then
            kind = lg.T_CLASS
            indent = indent:len()
            found = true
            break
        end

        -- match a variable
        name = string.match(line, "^([_%a%d]-)%s*=[^=]")
        if name then
            kind = lg.T_VARIABLE
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

--- Export the python structure of a buffer containing python code
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgp.export_structure(str)
    local root = lgp.Node(tree.SEP)

    local classes   = lgp.Node('Classes')
    local functions = lgp.Node('Functions')
    local variables = lgp.Node('Variables')

    root:append(classes)
    root:append(functions)
    root:append(variables)

    -- Extract structure from the buffer

    local parents = {}   -- table of parents indexed by indent
    local parent = nil
    local node
    local current_indent = 0

    local lines = str:split('\n')
    local tmp = lgp.Node(tree.SEP)
    for nb, line in ipairs(lines) do

        node = lgp.match_python_item(line)

        if node then
            node.line = nb
            if node.indent > current_indent then
                parent = parents[current_indent]
                current_indent = node.indent

            elseif node.indent < current_indent then
                if node.indent == 0 then
                    parent = tmp
                else
                    parent = parents[node.indent]:get_parent()
                end
                current_indent = node.indent

            else -- node.indent == current_indent then
                if node.indent == 0 then
                    parent = tmp
                else
                    -- do nothing special
                end
            end
            parent:append(node)
            parents[node.indent] = node
        end
    end

    tmp:sort_children_rec()

    -- Format the tree properly

    for k, v in ipairs(tmp:get_children()) do
        if v.kind == lg.T_CLASS then
            classes:append(v)
        elseif v.kind == lg.T_FUNCTION then
            functions:append(v)
        elseif v.kind == lg.T_VARIABLE then
            variables:append(v)
        end
    end

    return root
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- Node inherit from tree.NodeSimple.
-- @type Node
lgp.Node = gen.class(lg.Node)

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
function lgp.Node:__init(name, kind, indent, line)
    lg.Node.__init(self, name, kind, line)
    self.indent = indent or 0
end

--- Return a representation of the current node.
-- Note: the order doesn't match the Node() constructor, but it is easier to read.
-- @treturn string Node(kind, name, line, indend).
function lgp.Node:__repr()
    -- Allow us to display the nodes in a readable way.
    return 'Node(' .. table.concat({self.kind, self.name, self.line, self.indent}, ', ') .. ')'
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgp
