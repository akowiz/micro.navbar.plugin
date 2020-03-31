--- @module navbar.supported.go

local lgg = {}


local gen  = require('../generic')
local tree = require('../tree')
local lg   = require('../lang')


local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Test a string and attempt to extract a lua item (function, etc.)
-- Notes: this is a crude attempt, it will work only on nicely formatted lua
-- script and it will break on ugly scrips (such as everything on 1 line).
-- @tparam string line A line of text to analyse.
-- @treturn {string, Node} An object recording the information about the item, or nil if we identify nothing.
function lgg.match_go_item(line)
    local indent = 0
    local name = nil
    local obj = nil
    local kind

    local node = nil
    local found = false
---[[
    while not found do

        -- match the package
        -- name = string.match(line, "^%spackage%s+([_.:%w]+)%s*")
        -- if name then
            -- kind = lg.T_PACKAGE
            -- found = true
            -- break
        -- end

        -- match a structure
        name = string.match(line, "^%s*type%s+([_%w]+)%s+struct%s*")
        if name then
            kind = lg.T_STRUCTURE
            found = true
            break
        end

        -- match a method
        -- func (name obj) M5
        obj, name = string.match(line, "^func%s*%([_%w]+%s+%*?([_%w]+)%)%s*([_%w]+)%s*%(")
        if name then
            name = obj .. '.' .. name
            kind = lg.T_FUNCTION
            found = true
            break
        end

        -- match a function
        name = string.match(line, "^func%s+([_%w]+)%s*%(")
        if name then
            kind = lg.T_FUNCTION
            found = true
            break
        end

        -- match a variable
        -- - this break on lines with multiple definitions.
        -- - this break on variables defined without var keyword.
        name = string.match(line, "^var%s+([_%w]+)%s*$")
        if name then
            kind = lg.T_VARIABLE
            found = true
            break
        end

        name = string.match(line, "^var%s+([_%w]+)%s*[_%w]*%s*=[^=]")
        if name then
            kind = lg.T_VARIABLE
            found = true
            break
        end

        -- match a constant
        name = string.match(line, "^const%s+([_%w]+)%s*[_%w]*%s*=[^=]")
        if name then
            kind = lg.T_CONSTANT
            found = true
            break
        end

        break
    end

    if found then
        node = lgg.Node(name, kind)
    end
--]]
    return node
end

--- Export the structure of a buffer containing a programming language.
-- @tparam string str The string (buffer content) to analyse.
-- @treturn Node A tree (made of Nodes) representing the structure.
function lgg.export_structure(str)
    local root = lgg.Node(tree.SEP)

    local structures = lgg.Node('Structures')
    local functions  = lgg.Node('Functions')
    local variables  = lgg.Node('Variables')
    local constants  = lgg.Node('Constants')

    root:append(structures)
    root:append(functions)
    root:append(variables)
    root:append(constants)

    -- Extract structure from the buffer

    local parent = nil
    local object
    local node

    local lines = str:split('\n')
    local tmp  = lgg.Node(tree.Sep)
    for nb, line in ipairs(lines) do

        node = lgg.match_go_item(line)
        if node then
            node.line = nb
            parent = tmp
            parent:append(node)
        end
    end

    tmp:sort_children_rec()

    -- Format the tree properly

    for k, v in ipairs(tmp:get_children()) do

        if v.kind == lg.T_STRUCTURE then
            structures:append(v)

        elseif v.kind == lg.T_FUNCTION then
            if not v.name:contains('.') then
                functions:append(v)
            else
                local items
                local name
                local current
                local item

                items = v.name:split('.')
                name = items[#items]   -- should always be 2
                obj  = items[#items-1] -- should always be 1

                current = structures:get_child_named(obj)
                if not current then
                    current = functions
                end
                v.name = name
                current:append(v)
            end

        elseif v.kind == lg.T_VARIABLE then
            variables:append(v)

        elseif v.kind == lg.T_CONSTANT then
            constants:append(v)
        end

    end

    return root
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- Node inherit from tree.NodeSimple.
-- @type Node
lgg.Node = gen.class(lg.Node)

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
function lgg.Node:__init(name, kind, line)
    lg.Node.__init(self, name, kind, line)
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgg
