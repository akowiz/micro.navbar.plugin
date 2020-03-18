#!/bin/env lua

--- @module navbar.generic
local gen = {}


-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- split function with a python semantic.
--   see http://lua-users.org/wiki/SplitJoin
-- @tparam string sep The character to use for the slit.
-- @tparam int max The maximun number of split.
-- @tparam string regex The regex to use for the split instead of sSeparator.
-- @return A table of string.
function string:split(sep, max, regex)
   assert(sep ~= '')
   assert(max == nil or max >= 1)

   local record = {}

   if self:len() > 0 then
      local plain = not regex
      max = max or -1

      local field, start = 1, 1
      local first, last = self:find(sep, start, plain)
      while first and max ~= 0 do
         record[field] = self:sub(start, first-1)
         field = field + 1
         start = last + 1
         first, last = self:find(sep, start, plain)
         max = max-1
      end
      record[field] = self:sub(start)
   end

   return record
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
