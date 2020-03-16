#!/bin/env lua

--- @module navbar.navbar_python
local nbp = {}


nbp.T_NONE = 0
nbp.T_CLASS = 1
nbp.T_FUNCTION = 2
nbp.T_CONSTANT = 3

nbp.ROOT = '/'
nbp.STEP = 2


-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Split function with a python semantic
--   see http://lua-users.org/wiki/SplitJoin
function string:split(sSeparator, nMax, bRegexp)
   assert(sSeparator ~= '')
   assert(nMax == nil or nMax >= 1)

   local aRecord = {}

   if self:len() > 0 then
      local bPlain = not bRegexp
      nMax = nMax or -1

      local nField, nStart = 1, 1
      local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
      while nFirst and nMax ~= 0 do
         aRecord[nField] = self:sub(nStart, nFirst-1)
         nField = nField+1
         nStart = nLast+1
         nFirst,nLast = self:find(sSeparator, nStart, bPlain)
         nMax = nMax-1
      end
      aRecord[nField] = self:sub(nStart)
   end

   return aRecord
end

-- Return true if table == {}, false otherwise
function nbp.isempty(table)
    return next(table) == nil
end

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
    node.parent = self
    table.insert(self.children, node)
end

function nbp.tree_style(stylename, padding)
    stylename = stylename or 'bare'
    padding = padding or 0

    ret = {}
    if     stylename == 'bare' then
        ret['1st_level_1st_key']        = '.'..string.rep(' ', padding)..' '
        ret['1st_level_1st_key_open']   = 'v'..string.rep(' ', padding)..' '
        ret['1st_level_1st_key_closed'] = '>'..string.rep(' ', padding)..' '
        ret['nth_key']        = '.'..string.rep(' ', padding)..' '
        ret['nth_key_open']   = 'v'..string.rep(' ', padding)..' '
        ret['nth_key_closed'] = '>'..string.rep(' ', padding)..' '
        ret['lst_key']        = '.'..string.rep(' ', padding)..' '
        ret['lst_key_open']   = 'v'..string.rep(' ', padding)..' '
        ret['lst_key_closed'] = '>'..string.rep(' ', padding)..' '
        ret['empty'] = ' '..string.rep(' ', padding)..' '
        ret['link']  = ' '..string.rep(' ', padding)..' '

        ret['last_item'] = '.'
        ret['last_item_closed'] = '>'
        ret['last_item_open'] = 'v'
        ret['default'] = ' '
        ret['item_single'] = '.'
        ret['item_open'] = 'v'
        ret['item_closed'] = '>'

    elseif stylename == 'ascii' then
        ret['1st_level_1st_key']        = '.'..string.rep(' ', padding)..' '
        ret['1st_level_1st_key_open']   = '-'..string.rep(' ', padding)..' '
        ret['1st_level_1st_key_closed'] = '+'..string.rep(' ', padding)..' '
        ret['nth_key']        = '.'..string.rep(' ', padding)..' '
        ret['nth_key_open']   = '-'..string.rep(' ', padding)..' '
        ret['nth_key_closed'] = '+'..string.rep(' ', padding)..' '
        ret['lst_key']        = 'L'..string.rep(' ', padding)..' '
        ret['lst_key_open']   = '-'..string.rep(' ', padding)..' '
        ret['lst_key_closed'] = '+'..string.rep(' ', padding)..' '
        ret['empty'] = ' '..string.rep(' ', padding)..' '
        ret['link']  = '|'..string.rep(' ', padding)..' '

        ret['last_item'] = 'L'
        ret['last_item_closed'] = '>'
        ret['last_item_open'] = 'v'
        ret['default'] = '|'
        ret['item_single'] = '+'
        ret['item_open'] = 'v'
        ret['item_closed'] = '>'

    elseif stylename == 'box' then
        ret['1st_level_1st_key']        = '├'..string.rep('─', padding)..' '
        ret['1st_level_1st_key_open']   = '├'..string.rep('─', padding)..' '
        ret['1st_level_1st_key_closed'] = '╞'..string.rep('═', padding)..' '
        ret['nth_key']        = '├'..string.rep('─', padding)..' '
        ret['nth_key_open']   = '├'..string.rep('─', padding)..' '
        ret['nth_key_closed'] = '╞'..string.rep('═', padding)..' '
        ret['lst_key']        = '└'..string.rep('─', padding)..' '
        ret['lst_key_open']   = '└'..string.rep('─', padding)..' '
        ret['lst_key_closed'] = '╘'..string.rep('═', padding)..' '
        ret['empty'] = ' '..string.rep(' ', padding)..' '
        ret['link']  = '│'..string.rep(' ', padding)..' '

        ret['last_item'] = '└'
        ret['last_item_closed'] = '╘'
        ret['last_item_open'] = '└'
        ret['default'] = '│'
        ret['item_single'] = '├'
        ret['item_open'] = '├'
        ret['item_closed'] = '╞'

    end
    return ret
end

function nbp.ReturnTree(style, tab, tree, padding, level)
    padding = padding or ""
    level = level or 1
    local tree = tree or {}
    local i = 0
    local key_count = #tab
    local lead
    for k, node in ipairs(tab) do
        i = i + 1
        if key_count == i then -- Last key
            if level == 1 and i == 1 then -- Single key at first level
                table.insert(tree, node.name)
                if not node.closed then
                    nbp.ReturnTree(style, node.children, tree, nil, level + 1)
                end
            else
                lead = style['lst_key']
                if not nbp.isempty(node.children) then
                    if node.closed then
                        lead = style['lst_key_closed']
                    else
                        lead = style['lst_key_open']
                    end
                end
                table.insert(tree, padding .. lead .. node.name)
                if not node.closed then
                    lead = style['empty']
                    nbp.ReturnTree(style, node.children, tree, padding .. lead, level + 1)
                end
            end
        else -- Not last key
            if level == 1 and i == 1 then -- First level, first key
                lead = style['1st_level_1st_key']
                if not nbp.isempty(node.children) then
                    if node.closed then
                        lead = style['1st_level_1st_key_closed']
                    else
                        lead = style['1st_level_1st_key_open']
                    end
                end
                table.insert(tree, padding .. lead .. node.name)
            else
                lead = style['nth_key']
                if not nbp.isempty(node.children) then
                    if node.closed then
                        lead = style['nth_key_closed']
                    else
                        lead = style['nth_key_open']
                    end
                end
                table.insert(tree, padding .. lead .. node.name)
            end
            lead = style['link']
            if not node.closed then
                nbp.ReturnTree(style, node.children, tree, padding .. lead, level + 1)
            end
        end
    end
    return table.concat(tree, "\n")
end

function nbp.Node:tree2(stylename, spacing, hide_me)
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false

    local style = nbp.tree_style(stylename, spacing)
    local tree = {}
    local lead = nil
    local padding = nil

    if not hide_me then
        padding = style['empty']
        if nbp.isempty(self.children) then
            lead = style['lst_key']
        else
            if self.closed then
                lead = style['lst_key_closed']
            else
                lead = style['lst_key_open']
            end
        end
        table.insert(tree, lead .. self.name)
    end

    if (not nbp.isempty(self.children)) and (not self.closed) then
        nbp.ReturnTree(style, self.children, tree, padding)
    end

    return table.concat(tree, "\n")
end


--[[ Function to display a node and its children in a recursive way.

Notes: You do not need to call this function directly, instead you should just
use Node:tree().

Parameters
----------
    style : table
        A table containing the style to use.
    indent : int
        The number of characters to use as leading indent.
    last : bool
        True if the current item is the last children of the paren node.

Returns
-------
    string
        The tree of the node and its children in a string.
--]]
function nbp.Node:tree_recurse(style, indent, last)
    local lead = style['item_single']
    local default = style['default']
    local name
    local names = {}

    if last then
        lead = style['last_item']
    end

    names[1] = '' -- placeholder
    if #self.children > 0 then
        if self.closed then
            if last then
                lead = style['last_item_closed']
            else
                lead = style['item_closed']
            end
        else
            if last then
                lead = style['last_item_open']
            else
                lead = style['item_open']
            end
        end
        table.sort(self.children)
        for k, v in ipairs(self.children) do
            local last = (k == #self.children)
            names[#names+1] = v:tree_recurse(style, indent + nbp.STEP, last)
        end
    end

    if self.name == nbp.ROOT then
        name = nbp.ROOT
    else
        if last then
            default = ' '
        end
        name = string.rep(default..' ', (indent/nbp.STEP)) .. lead .. ' ' .. self.name
    end
    names[1] = name

    return table.concat(names, "\n")
end

--[[ Function to display a node and its children.


Parameters
----------
    style : string
        The style to use (one of 'bare', 'ascii', 'box') to display the tree.

Returns
-------
    string
        The tree of the node and its children in a string.
--]]
function nbp.Node:tree(style)
    style = style or 'bare'
    style = nbp.tree_style(style)
    return self:tree_recurse(style, 0, false)
end


-------------------------------------------------------------------------------
-- Main Functions
-------------------------------------------------------------------------------

-- Export the python structure of a buffer containing python code
function nbp.export_structure_python(str)
    local root = nbp.Node:new('Root')

    local parents = { [0] = nil }   -- table of parents indexed by indent

    -- Extract structure from the buffer

    local lines = str:split('\n')
    for nb, line in ipairs(lines) do

        local indent, name = string.match(line, "^(%s*)class%s*([_%a]-)%s*[(:]")
        if name then
            if (indent == '') or (indent == 0) then
                node = nbp.Node:new(name, nbp.T_CLASS, nb, indent:len())
                root:append(node)
            else
                -- print("Ignore class "..name)
                -- print("indent = "..tostring(indent))
                -- We ignore the classes defined inside other items for the moment.
            end
        end

        local indent, name = string.match(line, "^(%s*)def%s*([_%a]-)%s*%(")
        if name then
            if (indent == '') or (indent == 0) then
                node = nbp.Node:new(name, nbp.T_FUNCTION, nb, indent:len())
                root:append(node)
            else
                -- print("Ignore function "..name)
                -- print("indent = "..tostring(indent))
                -- We ignore the functions defined inside other items for the moment.
            end
        end

        local name = string.match(line, "^([_%a]-)%s*=[^=]")
        if name then
            -- Notes: we only considers constants with indent of 0
            node = nbp.Node:new(name, nbp.T_CONSTANT, nb, 0)
            root:append(node)
        end

    end

    return root
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return nbp
