--- @module navbar.lang_lua

local nvb_path = os.getenv("HOME") .. '/.config/micro/plug/navbar/'
if not string.find(package.path, nvb_path) then
    package.path = nvb_path .. "?.lua;" .. package.path
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

--- Export the structure of a buffer containing a programming language.
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgl.export_structure(str)
    local root = lgl.Node(tree.SEP)

    local objects   = lgl.Node('Objects')
    local functions = lgl.Node('Functions')
    local variables = lgl.Node('Variables')

    root:append(objects)
    root:append(functions)
    root:append(variables)

    -- Extract structure from the buffer

    local parent = nil
    local object
    local node

    local lines = str:split('\n')
    local tmp  = lgl.Node(tree.Sep)
    for nb, line in ipairs(lines) do

        node = lgl.match_lua_item(line)
        if node then
            node.line = nb
            parent = tmp
            parent:append(node)
        end
    end

    tmp:sort_children_rec()

    -- Format the tree properly

    for k, v in ipairs(tmp:get_children()) do

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

    return root
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
