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
    return 'Node(' .. table.concat({self.name, self.kind, self.line, self.indent, self.parent}, ', ') .. ')'
end


-- Export the python structure of a buffer containing python code
function string:export_structure_python()
    local aTable = {}

    for k, v in pairs({'classes', 'functions', 'constants'}) do
        aTable[v] = {}
        empty = nbp.Node:new()
        table.insert(aTable[v], empty)
    end

    return aTable
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return nbp
