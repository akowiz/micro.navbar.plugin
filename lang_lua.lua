--- @module navbar.lang_lua

local nvb_path = "navbar/?.lua;"
if not string.find(package.path, nvb_path) then
    package.path = nvb_path .. package.path
end

local lgl = {}


local gen  = require('generic')
local tree = require('tree')
local lg   = require('lang')


local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Test a string and attempt to extract a lua item (function, etc.)
-- Notes: this is a crude attempt, it will work only on nicely formatted lua
-- script and it will break on ugly scrips (such as everything on 1 line).
-- @tparam string line A line of text to analyse.
-- @treturn {string, Node} An object recording the information about the item, or nil if we identify nothing.
function lgl.match_lua_item(line)
    local indent = 0
    local name = nil
    local kind

    local node = nil
    local found = false

    while not found do

        -- match a function
        name = string.match(line, "^local%s*function%s+([_.:%w]-)%s*%(")
        if name then
            kind = lg.T_FUNCTION
            found = true
            break
        end

        name = string.match(line, "^%s*function%s+([_.:%w]-)%s*%(")
        if name then
            kind = lg.T_FUNCTION
            found = true
            break
        end

        -- match a variable
        name = string.match(line, "^local%s*([_.:%w]-)%s*=[^=]")
        if name then
            kind = lg.T_VARIABLE
            found = true
            break
        end

        name = string.match(line, "^([_.:%w]-)%s*=[^=]")
        if name then
            kind = lg.T_VARIABLE
            found = true
            break
        end

        break
    end

    if found then
        node = lgl.Node(name, kind)
    end

    return node
end

--- Export the python structure of a buffer containing python code
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgl.export_structure(str)
    local root = lgl.Node('/')

    local parent = nil
    local object
    local node

    -- Extract structure from the buffer

    local lines = str:split('\n')
    for nb, line in ipairs(lines) do

        node = lgl.match_lua_item(line)
        if node then
            node.line = nb
            parent = root
            parent:append(node)
        end
    end

    root:sort_children_rec()

    return root
end

--- Convert a tree (made of Nodes) into 3 trees (made of Nodes)
-- @tparam Node tree The tree to convert.
-- @treturn table A list of {display_text, line}.
function lgl.tree_to_navbar(tree, stylename, spacing)
    stylename = stylename or 'bare'
    spacing = spacing or 0

    local ttree
    local objects   = lgl.Node('Objects')
    local functions = lgl.Node('Functions')
    local variables = lgl.Node('Variables')

    local children = tree:get_children()
    table.sort(children)

    for k, v in ipairs(children) do

        if v.kind == lg.T_OBJECT then
            objects:append(v)

        elseif v.kind == lg.T_FUNCTION then
            if not (v.name:contains(':') or v.name:contains('.')) then
                functions:append(v)
            else
                local items
                local name
                local current
                local item

                if v.name:contains(':') then
                    items, name = string.match(v.name, "([._%w]+)[:]([_%w]+)")
                    items = items:split('.')
                else
                    items = v.name:split('.')
                    name = items[#items]
                    items[#items] = nil
                end

                current = objects
                for i, o in ipairs(items) do
                    item = current:get_child_named(o)
                    if item == nil then
                        item = lgl.Node(o, lg.T_OBJECT)
                        current:append(item)
                        current = item
                    else
                        current = item
                    end
                end
                v.name = name
                current:append(v)
            end

        elseif v.kind == lg.T_VARIABLE then
            if v.name:contains('.') then
                local items
                local name
                local current
                local item

                items = v.name:split('.')
                name = items[#items]
                items[#items] = nil
                v.name = name

                current = objects
                for i, o in ipairs(items) do
                    item = current:get_child_named(o)
                    if item == nil then
                        item = lgl.Node(o, lg.T_OBJECT)
                        current:append(item)
                        current = item
                    else
                        current = item
                    end
                end
                item = current:get_child_named(v.name)
                if item then
                    item.line = v.line
                else
                    current:append(v)
                end
            else
                item = objects:get_child_named(v.name)
                if item then
                    item.line = v.line
                else
                    variables:append(v)
                end
            end
        end
    end

    local empty_line = lg.TreeLine()

    ttree = objects:list_tree(stylename, spacing)
    table.insert(ttree, empty_line)

    for _, tl in ipairs(functions:list_tree(stylename, spacing)) do
        table.insert(ttree, tl)
    end
    table.insert(ttree, empty_line)

    for _, tl in ipairs(variables:list_tree(stylename, spacing)) do
        table.insert(ttree, tl)
    end

    return ttree
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- Node inherit from tree.NodeSimple.
-- @type Node
lgl.Node = gen.class(lg.Node)

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
function lgl.Node:__init(name, kind, line)
    lg.Node.__init(self, name, kind, line)
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgl
