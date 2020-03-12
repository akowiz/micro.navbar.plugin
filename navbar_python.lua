#!/bin/env lua

T_NONE = 99
T_CLASS = 1
T_FUNCTION = 2
T_CONSTANT = 4


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

Node = { name = '', kind = T_NONE, line = 0, indent = 0, parent = nil, }

function Node:new(o, n, k, l, i, p)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.name = n or ''
    self.kind = k or T_NONE
    self.line = l or 0
    self.indent = i or 0
    self.parent = p
    return o
end


-- Export the python structure of a buffer containing python code
function string:export_structure_python()
    local aTable = {}

    for k, v in pairs({'classes', 'functions', 'constants'}) do
        aTable[v] = {}
        table.insert(aTable[v], 'value')
    end

    return aTable
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return {
    T_CLASS = T_CLASS,
    T_FUNCTION = T_FUNCTION,
    T_CONSTANT = T_CONSTANT,
    split = split,
    export_structure_python = export_structure_python,
    Node = Node,
}