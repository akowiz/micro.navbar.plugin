#!/bin/env lua

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

-- Convert lgp.T_XXX into human readeable string
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

-- Test a string and attempt to extract a python item (class, function,
-- variable). If found, return the corresponding Node object, else nil.
function lgp.match_python_item(line)
    local indent = 0
    local name
    local kind
    local ret = nil

    -- match a function
    indent, name = string.match(line, "^(%s*)def%s*([_%a%d]-)%s*%(")
    if name then
        kind = lgp.T_FUNCTION
        indent = indent:len()
        goto mpi_continue
    end

    -- match a class
    indent, name = string.match(line, "^(%s*)class%s*([_%a%d]-)%s*[(:]")
    if name then
        kind = lgp.T_CLASS
        indent = indent:len()
        goto mpi_continue
    end

    -- match a constant
    name = string.match(line, "^([_%a%d]-)%s*=[^=]")
    if name then
        kind = lgp.T_CONSTANT
        goto mpi_continue
    end

    ::mpi_continue::

    if name then
        ret = lgp.Node(name, kind, indent)
    end

    return ret
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

-- Class Node

lgp.Node = gen.class(tree.NodeBase)

function lgp.Node:__init(name, kind, indent, line, closed)
    tree.NodeBase.__init(self)
    self.name = name or ''
    self.kind = kind or lgp.T_NONE
    self.line = line or 0
    self.indent = indent or 0
    self.closed = closed or false
end

function lgp.Node:__lt(node)
    -- Allow us to sort the nodes by kind, and then by name
    return (self.kind < node.kind) or ((self.kind == node.kind) and (self.name < node.name))
end

function lgp.Node:__repr()
    -- Allow us to display the nodes in a readable way.
    return 'Node(' .. table.concat({self.kind, self.name, self.line, self.indent}, ', ') .. ')'
end

function lgp.Node:get_label()
    return tostring(self.name)
end

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

-- Export the python structure of a buffer containing python code
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

function lgp.tree_to_navbar(tree)
    local root      = lgp.Node('/')
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

    root:append(classes)
    root:append(functions)
    root:append(constants)
    table.sort(root:get_children())

    return root
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return lgp
