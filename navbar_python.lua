#!/bin/env lua

local gen = require('generic')

--- @module navbar.navbar_python
local nbp = {}


nbp.T_NONE = 0
nbp.T_CLASS = 1
nbp.T_FUNCTION = 2
nbp.T_CONSTANT = 3

nbp.ROOT = '/'
nbp.STEP = 2

local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Convert nbp.T_XXX into human readeable string
function nbp.kind_to_str(kind)
    local ret = 'None'
    if kind == nbp.T_CLASS then
        ret = 'Class'
    elseif kind == nbp.T_FUNCTION then
        ret = 'Function'
    elseif kind == nbp.T_CONSTANT then
        ret = 'Constant'
    end
    return ret
end

-- Test a string and attempt to extract a python item (class, function,
-- variable). If found, return the corresponding Node object, else nil.
function nbp.match_python_item(line)
    local indent = 0
    local name
    local kind
    local ret = nil

    -- match a function
    indent, name = string.match(line, "^(%s*)def%s*([_%a%d]-)%s*%(")
    if name then
        kind = nbp.T_FUNCTION
        indent = indent:len()
        goto mpi_continue
    end

    -- match a class
    indent, name = string.match(line, "^(%s*)class%s*([_%a%d]-)%s*[(:]")
    if name then
        kind = nbp.T_CLASS
        indent = indent:len()
        goto mpi_continue
    end

    -- match a constant
    name = string.match(line, "^([_%a%d]-)%s*=[^=]")
    if name then
        kind = nbp.T_CONSTANT
        goto mpi_continue
    end

    ::mpi_continue::

    if name then
        ret = nbp.Node:new(name, kind, indent)
    end

    return ret
end


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

-- Class Node

nbp.Node = { name='', kind=nbp.T_NONE, line=0, indent=0, closed=false,
             parent=nil, children={} }

function nbp.Node:new(n, k, i, l, c)
    local o = {}
    self.__index = self
    setmetatable(o, nbp.Node)

    o.name = n or nbp.Node.name
    o.kind = k or nbp.Node.kind
    o.indent = i or nbp.Node.indent
    o.line = l or nbp.Node.line
    o.closed = c or nbp.Node.closed
    o.children = {}
    o.parent = nil

    return o
end

function nbp.Node:__lt(node)
    -- Allow us to sort the nodes by kind, and then by name
    return (self.kind < node.kind) or ((self.kind == node.kind) and (self.name < node.name))
end

function nbp.Node:__repr()
    -- Allow us to display the nodes in a readable way.
    return 'Node(' .. table.concat({self.kind, self.name, self.line, self.indent}, ', ') .. ')'
end

function nbp.Node:__tostring()
    return self:__repr()
end

function nbp.Node:append(node)
    if DEBUG then
        local kind = nbp.kind_to_str(node.kind)
        print(kind .. ' ' .. tostring(node) .. ' added to ' .. tostring(self))
    end
    node.parent = self
    table.insert(self.children, node)
end

function nbp.tree_style(stylename, spacing)
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

local function get_lead(node, default, closed, open)
    local lead = default
    if not gen.isempty(node.children) then
        if node.closed then
            lead = closed
        else
            lead = open
        end
    end
    return lead
end

local function tree_rec(style, node, tree, padding, islast, isfirst)
    style = style or nbp.tree_style('bare', 0)
    tree = tree or {}
    padding = padding or ''

    local lead

    -- print(node.name, padding, islast, isfirst)

    if     islast then
        lead = get_lead(node,
                        style['lst_key'],
                        style['lst_key_closed'],
                        style['lst_key_open'])
    elseif isfirst then
        lead = get_lead(node,
                        style['1st_level_1st_key'],
                        style['1st_level_1st_key_closed'],
                        style['1st_level_1st_key_open'])
    else
        lead = get_lead(node,
                        style['nth_key'],
                        style['nth_key_closed'],
                        style['nth_key_open'])
    end
    table.insert(tree, padding .. lead .. node.name)

    if not node.closed then
        for k, child in ipairs(node.children) do
            local child_first = (k == 1)
            local child_last = (k == #node.children)
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

function nbp.Node:tree(stylename, spacing, hide_me)
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false

    local style = nbp.tree_style(stylename, spacing)
    local tree = {}
    local lead = nil
    local padding = nil

    if not hide_me then
        padding = style['empty']

        lead = get_lead(self,
                        style['root'],
                        style['root_closed'],
                        style['root_open'])
        table.insert(tree, lead .. self.name)
    end

    if not self.closed then
        for k, child in ipairs(self.children) do
            local isfirst = (k == 1)
            local islast  = (k == #self.children)
            tree_rec(style, child, tree, padding, islast, isfirst)
        end
    end

    return table.concat(tree, '\n')
end

function nbp.Node:sort_children_rec()
    if not gen.isempty(self.children) then
        table.sort(self.children)
        for k, child in ipairs(self.children) do
            child:sort_children_rec()
        end
    end
end

-------------------------------------------------------------------------------
-- Main Functions
-------------------------------------------------------------------------------

-- Export the python structure of a buffer containing python code
function nbp.export_structure_python(str)
    local root = nbp.Node:new(nbp.ROOT)

    local parents = {}   -- table of parents indexed by indent
    local parent = nil
    local node
    local current_indent = 0

    -- Extract structure from the buffer

    local lines = str:split('\n')
    for nb, line in ipairs(lines) do

        node = nbp.match_python_item(line)

        if node then
            if node.indent > current_indent then
                parent = parents[current_indent]
                current_indent = node.indent

            elseif node.indent < current_indent then
                if node.indent == 0 then
                    parent = root
                else
                    parent = parents[node.indent].parent
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

    if root then
        root:sort_children_rec()
    end

    return root
end

function nbp.tree_to_navbar(tree)
    local root      = nbp.Node:new(nbp.ROOT)
    local classes   = nbp.Node:new('Classes')
    local functions = nbp.Node:new('Functions')
    local constants = nbp.Node:new('Variables')

    for k, v in ipairs(tree.children) do
        if v.kind == nbp.T_CLASS then
            classes:append(v)
        elseif v.kind == nbp.T_FUNCTION then
            functions:append(v)
        elseif v.kind == nbp.T_CONSTANT then
            constants:append(v)
        end
    end

    root:append(classes)
    root:append(functions)
    root:append(constants)
    table.sort(root.children)

    return root
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return nbp
