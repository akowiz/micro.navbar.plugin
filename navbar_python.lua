#!/bin/env lua

local CLASSES = 1
local FUNCTIONS = 2
local CONSTANTS = 4


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


-- Export the python structure of a buffer containing python code
function string:export_structure_python()
    local aTable = {}

    for k, v in pairs({'classes', 'functions', 'constants'}) do
        aTable[v] = {}
        table.insert(aTable[v], 'value')
    end

    return aTable
end


return {
  CLASSES = CLASSES,
  FUNCTIONS = FUNCTIONS,
  CONSTANTS = CONSTANTS,
  split = split,
  export_structure_python = export_structure_python,
}