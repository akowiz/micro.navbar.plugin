#!/bin/env lua

--- @module navbar.generic
local gen = {}


-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- split function with a python semantic.
--   see http://lua-users.org/wiki/SplitJoin
-- @tparam string sSeparator The character to use for the slit.
-- @tparam int nMax The maximun number of split.
-- @tparam string bRegexp The regex to use for the split instead of sSeparator.
-- @return A table of string.
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

--- Return true if table == {}, false otherwise.
-- @tparam table table A table.
-- @return true if the table is {}, false otherwise.
function gen.is_empty(table)
    return next(table) == nil
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return gen
