--- @module navbar.lang

local nvb_path = "navbar/?.lua;"
if not string.find(package.path, nvb_path) then
    package.path = nvb_path .. package.path
end

local lgp = {}


local gen  = require('generic')
local tree = require('tree')
local lg   = require('lang')


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
-- @tparam bool closed Whether this node should be closed or not (i.e. whether children will be visible or not).
function lgp.Node:__init(name, kind, indent, line, closed)
    lg.Node.__init(self, name, kind, line, closed)
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
-- Main Functions
-------------------------------------------------------------------------------

--- Export the python structure of a buffer containing python code
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgp.export_structure(str)
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
            node.line = nb
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
-- @treturn table A list of {display_text, line}.
function lgp.tree_to_navbar(tree, stylename, spacing)
    stylename = stylename or 'bare'
    spacing = spacing or 0

    local ttree
    local classes   = lgp.Node('Classes')
    local functions = lgp.Node('Functions')
    local variables = lgp.Node('Variables')

    for k, v in ipairs(tree:get_children()) do
        if v.kind == lg.T_CLASS then
            classes:append(v)
        elseif v.kind == lg.T_FUNCTION then
            functions:append(v)
        elseif v.kind == lg.T_VARIABLE then
            variables:append(v)
        end
    end

    ttree = classes:list(stylename, spacing)
    table.insert(ttree, { text = '', node = nil })

    for _, v in ipairs(functions:list(stylename, spacing)) do
        table.insert(ttree, v)
    end
    table.insert(ttree, { text = '', node = nil })

    for _, v in ipairs(variables:list(stylename, spacing)) do
        table.insert(ttree, v)
    end

    return ttree
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgp
