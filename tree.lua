--- @module navbar.tree

-- Detecting the operating system to update the package.path
if not OS_TYPE then
    rawset(_G, "OS_TYPE",  (os.getenv("WINDIR") and 'windows') or 'posix')
    rawset(_G, "PATH_SEP",
        ((OS_TYPE == 'windows') and '\\') or
        ((OS_TYPE == 'posix') and '/')
    )
    rawset(_G, "PATH_PLUGIN", nil)

    local pkg_path_sep
    if OS_TYPE == 'posix' then
        pkg_path_sep = ';'
        PATH_PLUGIN = os.getenv("HOME")..'/.config/micro/plug/navbar/'
    elseif OS_TYPE == 'windows' then
        pkg_path_sep = ':'
        PATH_PLUGIN = nil
    end
    if PATH_PLUGIN then
        if not string.find(package.path, PATH_PLUGIN) then
            package.path = PATH_PLUGIN .. "?.lua" .. pkg_path_sep .. package.path
        end
    else
        error("Unsupported platform at the moment.")
    end
end

local tree = {}


local gen  = require('generic')


tree.SEP = '/'
local DEBUG = false

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

--- Return an array of string used to style a tree.
-- @tparam string stylename The name of the style to use (one of 'bare', 'ascii' or 'box').
-- @tparam int spacing The number of extra characters to use for the style. Default to 0.
-- @treturn table A table {key: string}
function tree.get_style(stylename, spacing)
    -- Returns an array containing the style to be used
    stylename = stylename or 'bare'
    spacing = spacing or 0

    ret = {}
    if     stylename == 'bare' then
        ret['root_d']   = '.'..string.rep('', spacing)..' '     -- root default
        ret['root_o']   = 'v'..string.rep('', spacing)..' '     -- root open
        ret['root_c']   = '>'..string.rep('', spacing)..' '     -- root closed
        ret['1st_d']    = '.'..string.rep(' ', spacing)..' '    -- 1st child default
        ret['1st_o']    = 'v'..string.rep(' ', spacing)..' '    -- 1st child open
        ret['1st_c']    = '>'..string.rep(' ', spacing)..' '    -- 1st child closed
        ret['nth_d']    = '.'..string.rep(' ', spacing)..' '    -- Nth child default
        ret['nth_o']    = 'v'..string.rep(' ', spacing)..' '    -- Nth child open
        ret['nth_c']    = '>'..string.rep(' ', spacing)..' '    -- Nth child closed
        ret['lst_d']    = '.'..string.rep(' ', spacing)..' '    -- last child default
        ret['lst_o']    = 'v'..string.rep(' ', spacing)..' '    -- last child open
        ret['lst_c']    = '>'..string.rep(' ', spacing)..' '    -- last child closed
        ret['empty']    = ' '..string.rep(' ', spacing)..' '    -- empty padding
        ret['link']     = ' '..string.rep(' ', spacing)..' '    -- padding with a vertical bar

    elseif stylename == 'ascii' then
        ret['root_d']   = '.'..string.rep('', spacing)..' '
        ret['root_o']   = '-'..string.rep('', spacing)..' '
        ret['root_c']   = '+'..string.rep('', spacing)..' '
        ret['1st_d']    = '.'..string.rep(' ', spacing)..' '
        ret['1st_o']    = '-'..string.rep(' ', spacing)..' '
        ret['1st_c']    = '+'..string.rep(' ', spacing)..' '
        ret['nth_d']    = '.'..string.rep(' ', spacing)..' '
        ret['nth_o']    = '-'..string.rep(' ', spacing)..' '
        ret['nth_c']    = '+'..string.rep(' ', spacing)..' '
        ret['lst_d']    = 'L'..string.rep(' ', spacing)..' '
        ret['lst_o']    = '-'..string.rep(' ', spacing)..' '
        ret['lst_c']    = '+'..string.rep(' ', spacing)..' '
        ret['empty']    = ' '..string.rep(' ', spacing)..' '
        ret['link']     = '|'..string.rep(' ', spacing)..' '

    elseif stylename == 'box' then
        ret['root_d']   = '.'..string.rep('', spacing)..' '
        ret['root_o']   = '▾'..string.rep('', spacing)..' '
        ret['root_c']   = '▸'..string.rep('', spacing)..' '
        ret['1st_d']    = '├'..string.rep('─', spacing)..' '
        ret['1st_o']    = '├'..string.rep('─', spacing)..' '
        ret['1st_c']    = '╞'..string.rep('═', spacing)..' '
        ret['nth_d']    = '├'..string.rep('─', spacing)..' '
        ret['nth_o']    = '├'..string.rep('─', spacing)..' '
        ret['nth_c']    = '╞'..string.rep('═', spacing)..' '
        ret['lst_d']    = '└'..string.rep('─', spacing)..' '
        ret['lst_o']    = '└'..string.rep('─', spacing)..' '
        ret['lst_c']    = '╘'..string.rep('═', spacing)..' '
        ret['empty']    = ' '..string.rep(' ', spacing)..' '
        ret['link']     = '│'..string.rep(' ', spacing)..' '

    end
    return ret
end

-------------------------------------------------------------------------------
-- Data Structures
-------------------------------------------------------------------------------

--- NodeBase provides a bare implementation of a tree.
-- @type NodeBase
tree.NodeBase = gen.class()

function tree.NodeBase:__init()
    self.__parent = nil
    self.__children = {}
end

--- Indicates how to order nodes.
-- Should be overriden in the class that inherit Node.
-- @tparam Node node The node to be compared to the current node.
-- @treturn bool true if the current node is 'before' node.
function tree.NodeBase:__lt(node)
    -- Default order is the alphabetic order on label.
    return self:get_label() < node:get_label()
end

--- Return a representation of the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn string Node(...).
function tree.NodeBase:__repr()
    -- Default to Node(label).
    return 'Node(' .. self:get_label() .. ')'
end

--- Return a string to be used whenever we use tostring(self)
-- @treturn string A string representing our current node.
function tree.NodeBase:__tostring()
    return self:__repr()
end

--- Add a children to the current node.
-- Both the current node and the child will be modified: Child will be added to
-- current node's children and current node will be set as the parent of the
-- child.
-- @tparam Node child The node to be added as a children of the current node.
function tree.NodeBase:append(child)
    local children = self:get_children()
    if DEBUG then
        print(tostring(child) .. ' added to ' .. tostring(self))
    end
    child:set_parent(self)
    table.insert(children, child)
end

--- Return a table of children from the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn table A table of the children from the current node.
function tree.NodeBase:get_children()
    return self.__children
end

--- Retrieve the label of the current node.
-- Should be overriden in the class that inherit Node.
-- @treturn string The label of the node.
function tree.NodeBase:get_label()
    -- Default label will be the address of the object.
    return tostring(self)
end

function tree.NodeBase:get_abs_label()
    local parents = {}

    local current = self
    local parent  = current:get_parent()

    parents[#parents+1] = current:get_label()

    while parent ~=  nil do
        current = parent
        parent  = current:get_parent()
        parents[#parents+1] = current:get_label()
    end
    gen.table_reverse(parents)

    return table.concat(parents, tree.SEP)
end

--- Return the parent of the current node.
-- @treturn Node The parent of the current node or nil if it doesn't have one.
function tree.NodeBase:get_parent()
    return self.__parent
end

--- Set the parent of the node.
-- @tparam Node node The parent of the node or nil if it doesn't have one.
function tree.NodeBase:set_parent(node)
    self.__parent = node
end

--- Select the lead characters for a node depending on the node's configuration.
-- The lead characters are displayed in from of the node's label in the tree.
-- @tparam string default Lead characters to be used if the node has no children.
-- @tparam string open Lead characters to be used if the node has children and is 'open'.
-- @tparam set closed List of abs_label that have to be closed.
-- @treturn string The lead characters to be used.
function tree.NodeBase:select_lead(default, open, close, closed)
    closed = closed or {}

    local lead = default
    local children = self:get_children()
    if not gen.is_empty(children) then
        lead = open
        if closed[self:get_abs_label()] then
            lead = close
        end
    end
    return lead
end

--- Recursively sort the children of the current node.
-- Only the order of the children in the various tables will be modified.
function tree.NodeBase:sort_children_rec()
    local children = self:get_children()
    if not gen.is_empty(children) then
        table.sort(children)
        for k, child in ipairs(children) do
            child:sort_children_rec()
        end
    end
end

--- Build a tree representation of the current node (node as root).
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam bool hide_me Set to true to 'hide' the current node (i.e. only display its' children)
-- @tparam table closed A list of string indicating that some nodes are closed (their children hidden).
-- @treturn string The tree in a string format.
function tree.NodeBase:tree(stylename, spacing, hide_me, closed)
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false
    closed  = closed or {}

    local tl_list = self:to_treelines(stylename, spacing, hide_me, closed)
    local str_list = {}
    local ret

    for _, tl in ipairs(tl_list) do
        str_list[#str_list+1] = tostring(tl)
    end

    ret = table.concat(str_list, '\n')
    return ret
end

--- Recursively build a tree representation of the current node as a list of TreeLine.
-- The table tree is used to accumulate the result of the recursion.
-- @tparam table style A style table to be used to display items.
-- @tparam Node node The node to process.
-- @tparam table list A table used to store all TreeLine objects generated.
-- @tparam string padding The string to use as padding for the current node.
-- @tparam bool islast Set to true if node is the last children.
-- @tparam bool isfirst Set to true if node is the first children.
-- @tparam table closed A list of string indicating that some nodes are closed (their children hidden).
local function to_treelines_rec(style, node, list, padding, islast, isfirst, closed)
    style = style or tree.get_style('bare', 0)
    list = list or {}
    padding = padding or ''
    closed = closed or {}

    local lead_type

    -- print(node.name, padding, islast, isfirst)

    if     islast then
        lead_type = node:select_lead('lst_d', 'lst_o', 'lst_c', closed)
    elseif isfirst then
        lead_type = node:select_lead('1st_d', '1st_o', '1st_c', closed)
    else
        lead_type = node:select_lead('nth_d', 'nth_o', 'nth_c', closed)
    end

    table.insert(list, tree.TreeLine(node, padding, lead_type, style))

    if not closed[node:get_abs_label()] then
        for k, child in ipairs(node:get_children()) do
            local child_first = (k == 1)
            local child_last = (k == #node:get_children())
            local child_padding
            if islast then
                child_padding = padding .. style['empty']
            else
                child_padding = padding .. style['link']
            end
            to_treelines_rec(style, child, list, child_padding, child_last, child_first, closed)
        end
    end
end

--- Build a tree representation of the current node (node as root).
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam bool hide_me Set to true to 'hide' the current node (i.e. only display its' children)
-- @tparam table closed A list of string indicating that some nodes are closed (their children hidden).
-- @treturn table A list of TreeLine() objects.
function tree.NodeBase:to_treelines(stylename, spacing, hide_me, closed)
    -- Returns the tree (current node as root) in a string.
    stylename = stylename or 'bare'
    spacing = spacing or 0
    hide_me = hide_me or false
    closed  = closed or {}

    local style = tree.get_style(stylename, spacing)
    local list = {}
    local lead_type = nil
    local padding = nil

    if not hide_me then
        lead_type = self:select_lead('root_d', 'root_o', 'root_c', closed)
        table.insert(list, tree.TreeLine(self, '', lead_type, style))
        padding = style['empty']
    end

    if not closed[self:get_abs_label()] then
        local children = self:get_children()
        for k, child in ipairs(children) do
            local isfirst = (k == 1)
            local islast  = (k == #children)
            to_treelines_rec(style, child, list, padding, islast, isfirst, closed)
        end
    end

    return list
end

--- Convert a tree (made of Nodes) into a list of TreeLine (used to display our navbar).
-- Note: the root of the tree will be hidden, we will only display the children.
-- @tparam string stylename The name of the string to be used. @see tree.get_style.
-- @tparam int spacing The number of extra characters to add in the lead.
-- @tparam table closed A list of string indicating that some nodes are closed (their children hidden).
-- @treturn table A list of TreeLine.
function tree.NodeBase:to_navbar(stylename, spacing, closed)
    stylename = stylename or 'bare'
    spacing = spacing or 0
    closed = closed or {}

    local tl_list = {}

    local empty_line = tree.TreeLine()

    for _, child in ipairs(self:get_children()) do
        for _, tl in ipairs(child:to_treelines(stylename, spacing, false, closed)) do
            table.insert(tl_list, tl)
        end
        table.insert(tl_list, empty_line)
    end

    return tl_list
end


--- NodeSimple inherit from NodeBase
-- @type NodeSimple
tree.NodeSimple = gen.class(tree.NodeBase)

--- Initialize our object.
-- @tparam string name The name of the node.
-- @tparam bool closed The status of the node, set to true to have it closed.
function tree.NodeSimple:__init(name, closed)
    tree.NodeBase.__init(self)
    self.name = name or ''
end

--- Retrieve the label of the node.
-- @treturn string The label of the node.
function tree.NodeSimple:get_label()
    return tostring(self.name)
end

--- Check if the node has a child named name
-- @tparam string name The name to look for among our children.
-- @treturn Node The node corresponding to the name or nil if not found.
function tree.NodeSimple:get_child_named(name)
    found = nil
    for _, c in ipairs(self:get_children()) do
        if c.name == name then
            found = c
            break
        end
    end
    return found
end


--- An item used to build a text tree line by line.
-- @type TreeLine
tree.TreeLine = gen.class()

--- Initialize Node
-- @tparam string name The name of the python object.
-- @tparam int kind The kind of object (T_NONE, T_CLASS, etc.)
-- @tparam int indent The level of indentation of the python code.
-- @tparam int line The line from the buffer where we can see this item.
-- @tparam bool closed Whether this node should be closed or not (i.e. whether children will be visible or not).
function tree.TreeLine:__init(node, padding, lead_type, style)
    self.node = node or nil
    self.padding = padding or ''
    self.lead_type = lead_type or nil
    self.style = style or tree.get_style('bare', 0)
end

--- Return a representation of the tree line.
-- @treturn string TreeLine(padding, lead_type, label).
function tree.TreeLine:__repr()
    local label = 'nil'
    if self.node ~= nil then
        label = self.node:get_label()
    end
    local lead = tostring(self.lead_type)
    return 'TreeLine(' .. table.concat({label, self.padding, lead}, ', ') .. ')'
end

--- Return the actual string of the TreeLine, ready to be displayed.
-- @treturn string The tree line.
function tree.TreeLine:__tostring()
    local label = ''
    if self.node ~= nil then
        label = self.node:get_label()
    end
    local lead = ''
    if self.lead_type ~= nil then
        lead = self.style[self.lead_type]
    end
    return self.padding .. lead .. label
end


-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

return tree