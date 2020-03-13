#!/bin/env lua

--- @module navbar.navbar_python
local nbp = {}


nbp.T_NONE = 0
nbp.T_CLASS = 1
nbp.T_FUNCTION = 2
nbp.T_CONSTANT = 3


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


-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

-- Meta Class

nbp.Node = { name='', kind=nbp.T_NONE, line=0, indent=0, parent=nil }

function nbp.Node:new(n, k, l, i, p)
    local o = {}
    self.__index = self
    setmetatable(o, nbp.Node)

    o.name = n or nbp.Node.name
    o.kind = k or nbp.Node.kind
    o.line = l or nbp.Node.line
    o.indent = i or nbp.Node.indent
    o.parent = p or nbp.Node.parent

    return o
end

function nbp.Node:__tostring()
    return self:__repr()
end

function nbp.Node:__repr()
    return 'Node(' .. table.concat({self.kind, self.name, self.line, self.indent, self.parent}, ', ') .. ')'
end

function nbp.compare_node(a, b)
    return a.name < b.name
end


-- Export the python structure of a buffer containing python code
function string:export_structure_python()
    local aTable = {}

    for k, v in ipairs({'classes', 'functions', 'constants'}) do
        aTable[v] = {}
    end

    local classes = aTable['classes']
    local functions = aTable['functions']
    local constants = aTable['constants']

    local parents = { [0] = nil }   -- table of parents indexed by indent

    -- Extract structure from the buffer

    local lines = self:split('\n')
    for nb, line in ipairs(lines) do

        local indent, name = string.match(line, "^(%s*)class%s*([_%a]-)%s*[(:]")
        if name then
            if (indent == '') or (indent == 0) then
                classes[#classes+1] = nbp.Node:new(name, nbp.T_CLASS, nb, indent:len())
            else
                -- print("Ignore class "..name)
                -- print("indent = "..tostring(indent))
                -- We ignore the classes defined inside other items for the moment.
            end
        end

        local indent, name = string.match(line, "^(%s*)def%s*([_%a]-)%s*%(")
        if name then
            if (indent == '') or (indent == 0) then
                functions[#functions+1] = nbp.Node:new(name, nbp.T_FUNCTION, nb, indent:len())
            else
                -- print("Ignore function "..name)
                -- print("indent = "..tostring(indent))
                -- We ignore the functions defined inside other items for the moment.
            end
        end

        local name = string.match(line, "^([_%a]-)%s*=[^=]")
        if name then
            -- Notes: we only considers constants with indent of 0
            constants[#constants+1] = nbp.Node:new(name, nbp.T_CONSTANT, nb, 0)
        end

    end

    -- Sort the tables

    table.sort(classes, nbp.compare_node)
    table.sort(functions, nbp.compare_node)
    table.sort(constants, nbp.compare_node)

--[[
    print()
    for _, node in ipairs(classes) do
        print(node)
    end
    for _, node in ipairs(functions) do
        print(node)
    end
    for _, node in ipairs(constants) do
        print(node)
    end
--]]

    return aTable
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return nbp
