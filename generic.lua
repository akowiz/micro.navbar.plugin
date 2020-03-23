--- @module navbar.generic

local gen = {}


-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Return true if string starts with start.
-- @tparam string start The string we are looking for.
-- @treturn bool true if the string starts with start.
function string:starts_with(start)
   return self:sub(1, #start) == start
end

--- Return true if string ends with ending.
-- @tparam string ending The string we are looking for.
-- @treturn bool true if the string ends with ending.
function string:ends_with(ending)
   return ending == "" or self:sub(-#ending) == ending
end

--- Return true if string contains str.
-- Notes: we will escape all punctuations contained in str first.
-- @tparam string str The string we are looking for.
-- @treturn bool true if the string contains str.
function string:contains(str)
    local pat = string.gsub(str, "%p", "%%%1")
    if string.find(self, pat) == nil then
        return false
    end
    return true
end

--- Split function with a python semantic.
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

--- Create a set from a list (table)
-- @tparam table list The table to use as source.
-- @treturn table A set (using the elements from list as keys)
function gen.set(list)
    local set = {}
    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

--- Clone/Copy a list (table)
-- @tparam table table The list to clone.
function gen.table_clone(list)
  return { table.unpack(list) }
end

--- Reverse a list (table).
-- Note: modify in place.
-- @tparam table table The list to reverse.
function gen.table_reverse(list)
    local i, j = 1, #list
    while i < j do
        list[i], list[j] = list[j], list[i]
        i = i + 1
        j = j - 1
    end
end

--- Return true if list == {}, false otherwise.
-- @tparam table table A table.
-- @return true if the table is {}, false otherwise.
function gen.is_empty(list)
    return next(list) == nil
end

--- Return true if val is present in list, false otherwise
-- @param val A value.
-- @tparam table table A list.
-- @treturn bool true if val is present in list.
function gen.is_in(val, list)
    for _, value in ipairs(list) do
        if value == val then
            return true
        end
    end
    return false
end

--- Return a Class object
--
-- @usage local Rectangle = gen.Class()
-- function Rectangle:__init(l, h) self.l = l or 0; self.h = h or 0 end
-- function Rectangle:surface() return self.l * self.h end
-- local Square = gen.Class(Rectangle)
-- function Square.__init(l) Rectangle.__init(self, l, l)
--
-- @param ... The list of classes this class inherit from (can be empty).
-- @return Class object.
function gen.class(...)
    -- "cls" is the new class
    local cls, bases = {}, {...}

    -- copy base class contents into the new class
    for i, base in ipairs(bases) do
        -- print(i, base)
        for k, v in pairs(base) do
            -- print(k, v)
            cls[k] = v
        end
    end

    -- set the class's __index, and start filling an "is_a" table that contains this class and all of its bases
    -- so you can do an "instance of" check using my_instance.is_a[MyClass]
    cls.__index, cls.is_a = cls, {[cls] = true}
    for i, base in ipairs(bases) do
        for c in pairs(base.is_a) do
            cls.is_a[c] = true
        end
        cls.is_a[base] = true
    end

    -- the class's __call metamethod
    setmetatable(cls, {__call = function (c, ...)
        local instance = setmetatable({}, c)
        -- run the init method if it's there
        local init = instance.__init
        if init then init(instance, ...) end
        return instance
    end})

    -- return the new class table, that's ready to fill with methods
    return cls
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return gen
