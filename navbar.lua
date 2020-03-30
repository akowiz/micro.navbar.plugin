VERSION = "0.0.1"

--- @module navbar

-- Detecting the operating system to update the package.path
-- Note: we need to add this at the begining of all modules loaded when micro
-- start (the modules to add language support do not need it because they are
-- loaded later). Therefore we can only use pure lua and not any of the go
-- functions provided by micro (because the only module that depends on micro
-- is navbar.lua, the others are independant of micro).
if not OS_TYPE then
    rawset(_G, "OS_TYPE",  (os.getenv("WINDIR") and 'windows') or 'posix')
    rawset(_G, "NVB_PATH", nil)
    local path_list_sep_lua = ';'
    if OS_TYPE == 'posix' then
        NVB_PATH = os.getenv("HOME")..'/.config/micro/plug/navbar/'
    elseif OS_TYPE == 'windows' then
        NVB_PATH = nil
    end
    if NVB_PATH then
        if not string.find(package.path, NVB_PATH) then
            package.path = NVB_PATH .. "?.lua" .. path_list_sep_lua .. package.path
        end
    else
        error("Unsupported platform at the moment.")
    end
end

local micro  = import("micro")
local config = import("micro/config")
local util   = import("micro/util")
local buffer = import("micro/buffer")

local gos    = import("os")
local gpath  = import("path/filepath")

local gen = require('generic')

local DISPLAY_NAME = 'navbar'
local SIZE_MIN = 15

local mainpanes = {} -- table of NavBufConf objects indexed by nvb_str(main_pane)
local treepanes = {} -- table of NavBufConf objects indexes by nvb_str(tree_pane)
local init_started = false
local languages_supported = {}

local path_sep = string.char(gos.PathSeparator)

local usr_local_share = gpath.Join(os.getenv("HOME"), '.local', 'share', 'micro', 'navbar')


-------------------------------------------------------------------------------

local function nvb_str(pane)
    local ret = 'nil'
    if pane then
        ret = pane:ID()..':'..pane.Buf:GetName()
    end
    return ret
end

local function buf_str(buf)
    ret = 'buf=nil'
    if buf then
        ret = 'buf='..buf:GetName()
    end
    return ret
end

local function convert_filename(filename)
    return filename:replace_all(path_sep, '%') .. '.closed'
end

local function get_languages_supported()
    local dir = gpath.Join(NVB_PATH, 'supported')
    micro.Log('  directory to scan = '..dir)
    local list = {}
    for _, file in ipairs(gen.scandir_posix(dir)) do
        local filetype = string.match(file, "^([_%a%d]+).lua")
        list[filetype] = { file=file, func=nil }
    end
    micro.Log('  languages supported = '..table.concat(gen.keys(list), ', '))
    return list
end

--- NavBufConf hold our configuration for the current buffer
-- type NavBufConf
local NavBufConf = gen.class()

function NavBufConf:__init(main)
    micro.Log('> NavBufConf:__init('..nvb_str(main)..')')

    self.main_pane = main or nil
    self.tree_pane = nil
    self.root = nil
    self.node_list = nil
    self.persistent = false
    self.closed = {}
    self.language = nil

    if (self.main_pane ~= nil) then
        self.language = self.main_pane.Buf:FileType()
    end

    micro.Log('< NavBufConf.__init')
end

function NavBufConf:supported()
    local languages = gen.keys(languages_supported)
    return self.language and gen.is_in(self.language, languages)
end

--- Display the configuration in a string.
function NavBufConf:__tostring()
    ret = {}
    table.insert(ret, 'main_pane: '..nvb_str(self.main_pane))
    table.insert(ret, 'tree_pane: '..nvb_str(self.tree_pane))
    table.insert(ret, 'language:  '..tostring(self.language))
    table.insert(ret, 'persistent:'..tostring(self.persistent))
    table.insert(ret, 'closed:    '..gen.set_tostring(self.closed))
    ret = table.concat(ret, ', ')
    return ret
end

--- Load the closed list from a file
function NavBufConf:closed_load()
    micro.Log('> NavBufConf:closed_load()')
    if not self.persistent then
        return
    end
    local abspath = self.main_pane.Buf.AbsPath
    local filename = gpath.Join(usr_local_share, convert_filename(abspath))
    local closed_nodes = {}

    -- create the directry if it doesn't exists
    micro.Log("  mkdir "..usr_local_share)
    gos.MkdirAll(usr_local_share, gos.ModePerm)

    -- read the file
    micro.Log("  reading "..filename)
    local file = io.open(filename, 'r')
    if file then
        for line in file:lines() do
            if line ~= '' then
                self.closed[line] = true
            end
        end
        file:close()
    end

    micro.Log('< NavBufConf:closed_load')
end

--- Save the closed list in a file
function NavBufConf:closed_save()
    micro.Log('> NavBufConf:closed_save()')
    if not self.persistent then
        return
    end
    local abspath = self.main_pane.Buf.AbsPath
    local filename = gpath.Join(usr_local_share, convert_filename(abspath))

    -- create the directry if it doesn't exists
    micro.Log("  mkdir "..usr_local_share)
    gos.MkdirAll(usr_local_share, gos.ModePerm)

    -- sort the data
    local closed_nodes = {}
    for k, v in pairs(self.closed) do
        closed_nodes[#closed_nodes+1] = k
    end
    table.sort(closed_nodes)

    -- write the file
    micro.Log("  writing "..filename)
    local file = io.open(filename, 'w+')
    if file then
        for _, v in ipairs(closed_nodes) do
            file:write(v..'\n')
        end
        file:flush()
        file:close()
    end
    micro.Log('< NavBufConf:closed_save')
end

-- class

-------------------------------------------------------------------------------

--- Retrieve an option, validate it against a list and provide default if value is not in list.
-- @tparam Buffer buf A buffer or nil to retrieve a global option.
-- @tparam string name Name of the setting.
-- @tparam values table Table of valid values.
-- @param default Default value to use if the current option is not in values (must be in values).
-- @return A valid option.
local function get_option_among_list(buf, name, values, default)
    micro.Log('> get_option_among_list('..buf_str(buf)..' name='..name..' default='..tostring(default)..')')
    local current = config.GetGlobalOption(name)
    -- micro.Log('  global option='..tostring(current))
    if (buf ~= nil) then
        local local_option = buf.Settings[name]
        -- micro.Log('  local option='..tostring(local_option))
        current = local_option
    end

    default = default or values[1]
    if current then
        if not gen.is_in(current, values) then
            if gen.is_in(default, values) then
                current = default
            else
                error('Default value ' .. default .. " for '" .. name .. "' is not in the list of valid values.")
            end
        end
    end
    micro.Log('  return '..tostring(current))
    micro.Log('< get_option_among_list')
    return current
end

--- Retrieve an option, validate it against a min and max, provide default if value is not in range.
-- @tparam Buffer buf A buffer or nil to retrieve a global option.
-- @tparam string name Name of the setting.
-- @tparam int lower Minimum value or nil if there is no minimum.
-- @tparam int upper Maximum value or nil if there is no maximum.
-- @treturn int A valid option.
local function get_option_among_range(buf, name, lower, upper)
    micro.Log('> get_option_among_range('..buf_str(buf)..' name='..name..' lower='..tostring(lower)..' upper='..tostring(upper)..')')
    local current = config.GetGlobalOption(name)
    -- micro.Log('  global option='..tostring(current))
    if (buf ~= nil) and (buf.Settings ~= nil) then
        local local_option = buf.Settings[name]
        if local_option then
            -- micro.Log('  buffer option='..tostring(local_option))
            current = local_option
        end
    end

    if current then
        if     lower and (current < lower) then
            current = lower
        elseif upper and (current > upper) then
            current = upper
        end
    end
    micro.Log('  return '..tostring(current))
    micro.Log('< get_option_among_range')
    return current
end

-------------------------------------------------------------------------------

-- Clear out all stuff in Micro's messenger
local function clear_messenger()
    micro.InfoBar():Reset()
    -- messenger:Reset()
    -- messenger:Clear()
end

-- Hightlights the line when you move the cursor up/down
-- @tparam pane pane The BufPanel object.
-- @tparam last_y int The line in the buffer.
local function select_line(pane, last_y)
    keepview = keepview or false
    local pane_id = nvb_str(pane)
    micro.Log('> select_line('..pane_id..', '..tostring(last_y)..')')

    local conf = treepanes[pane_id]

    if conf then

        local cursor_y  = conf.tree_pane.Cursor.Y
        local view      = conf.tree_pane:GetView()
        local height    = view.Height
        local startline = view.StartLine
        local lines     = conf.tree_pane.Buf:LinesNum()

        micro.Log('S tree_pane.cursor_y = '..tostring(cursor_y))
        micro.Log('S tree_pane.height = '..tostring(height))
        micro.Log('S tree_pane.lines = '..tostring(lines))
        micro.Log('S tree_pane.startline = '..tostring(startline))

        -- Make last_y optional
        if last_y ~= nil then
            -- Don't let them move past ".." by checking the result first
            if last_y > 1 then
                -- If the last position was valid, move back to it
                conf.tree_pane.Cursor.Loc.Y = last_y
            end
        else
            local pos_y = conf.tree_pane.Cursor.Loc.Y
            if pos_y < 2 then
                -- Put the cursor on the ".." if it's above it
                startline = 0
                conf.tree_pane.Cursor.Loc.Y = 2
            end
        end

        if lines <= height then
            startline = 0
        end
        -- Highlight the current line where the cursor is
        conf.tree_pane.Cursor:SelectLine()
    end
    micro.Log('< select_line')
end

-- Moves the cursor to the top in tree_view
local function move_cursor_top(pane)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]
    local view = pane:GetView()

    -- line to go to
    if conf then
        view.StartLine = 0
        pane.Cursor.Loc.Y = 2
    else
        view.StartLine = 0
        pane.Cursor.Loc.Y = 0
    end

    -- select the line after moving
    select_line(pane, nil)
end


local function refresh_structure(pane)
    micro.Log('> refresh_structure('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id] or treepanes[pane_id]

    if conf and conf:supported() then
        local language = conf.language
        local bytes = util.String(conf.main_pane.Buf:Bytes())

        conf.root = nil
        if not languages_supported[language].func then
            local required = gpath.Join('supported', language)
            micro.Log(' required='..required)
            local mod = require(required)
            languages_supported[language].func = mod.export_structure
        end

        -- call the export_structure() for our language
        conf.root = languages_supported[language].func(bytes)
    end

    micro.Log('< refresh_structure()')
end

--- Return the content (string) of the tree view to be displayed.
local function display_content(pane)
    micro.Log('> display_content('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id] or treepanes[pane_id]

    local buf = conf.main_pane.Buf
    local ttype  = get_option_among_list(buf, "navbar.treestyle", {'bare', 'ascii', 'box'})
    local tspace = get_option_among_range(bur, "navbar.treestyle_spacing", 0, nil)

    local tl_list = {}
    local display_text = {}

    if conf.root then
        tl_list = conf.root:to_navbar(ttype, tspace, conf.closed)
    end

    conf.node_list = {}
    for _, tl in ipairs(tl_list) do
        display_text[#display_text+1] = tostring(tl)
        if tl.node ~= nil then
            conf.node_list[#conf.node_list+1] = tl.node
        else
            conf.node_list[#conf.node_list+1] = false
        end
    end

    local ret = table.concat(display_text, '\n')
    micro.Log('< display_content')
    return ret
end

local function refresh_view(pane)
    micro.Log('> refresh_view('..nvb_str(pane)..')')
    clear_messenger()

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id] or treepanes[pane_id]

    local content = display_content(conf.main_pane)

    -- delete everything in the tree_view
    conf.tree_pane.Buf.EventHandler:Remove(
        conf.tree_pane.Buf:Start(),
        conf.tree_pane.Buf:End())

    -- display a new tree_view
    conf.tree_pane.Buf.EventHandler:Insert(
        conf.tree_pane.Buf:Start(), '» Symbols »\n\n')
    conf.tree_pane.Buf.EventHandler:Insert(
        conf.tree_pane.Buf:End(), content)

    -- this redraw the main view, which we might not need actually
    -- conf.tree_pane:Tab():Resize()

    micro.Log('< refresh_view')
end

--- Helper function to open a side panel with our navigation bar.
local function open_tree(pane)
    micro.Log('> open_tree('..nvb_str(pane)..')')

    local main_pane = pane
    local main_id = nvb_str(main_pane)

    local conf = NavBufConf(main_pane)
    mainpanes[main_id] = conf

    micro.Log('  conf.lang= '..tostring(conf.language))
    if not conf:supported() then
        micro.InfoBar():Error(DISPLAY_NAME..": "..conf.language.." language is currently not supported.")
        return
    end

    -- Open a new Vsplit (on the very left)
    local name = main_pane.Buf:GetName()
    local tree_pane = pane:VSplitIndex(buffer.NewBuffer("", name..'~'), false)

    -- Save the new view so we can access it later
    conf.tree_pane = tree_pane
    treepanes[nvb_str(tree_pane)] = conf

    -- Set the width of tree_view (in characters)
    local size = get_option_among_range(main_pane.Buf, 'navbar.treeview_size', SIZE_MIN)
    conf.tree_pane:ResizePane(size)

    local persistent = get_option_among_list(main_pane.Buf, 'navbar.persistent', {true, false}, false)
    conf.persistent = persistent

    -- Set the type to unsavable
    -- tree_view.Buf.Type = buffer.BTLog
    conf.tree_pane.Buf.Type.Scratch = true
    conf.tree_pane.Buf.Type.Readonly = true

    -- Set the various display settings, but only on our view (by using
    -- SetLocalOption instead of SetOption)

    -- Set the softwrap value for treeview
    local sw = get_option_among_list(main_pane.Buf, 'navbar.softwrap', {true, false}, false)
    conf.tree_pane.Buf:SetOptionNative("softwrap", sw)

    -- No line numbering
    conf.tree_pane.Buf:SetOptionNative("ruler", false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    conf.tree_pane.Buf:SetOptionNative("autosave", false)
    -- Don't show the statusline to differentiate the view from normal views
    conf.tree_pane.Buf:SetOptionNative("statusformatr", "")
    conf.tree_pane.Buf:SetOptionNative("statusformatl", DISPLAY_NAME)
    conf.tree_pane.Buf:SetOptionNative("scrollbar", false)

    -- Display the content
    conf:closed_load()
    refresh_structure(main_pane)
    refresh_view(main_pane)

    -- Move the cursor to the top
    move_cursor_top(conf.tree_pane)

    for k, cnf in pairs(mainpanes) do
        micro.Log('  mainpanes['..k..']: '..tostring(cnf))
    end
    for k, cnf in pairs(treepanes) do
        micro.Log('  treepanes['..k..']: '..tostring(cnf))
    end

    micro.Log('< open_tree')
end

--- Helper function to close the side panel containing our navigation bar.
local function close_tree(pane)
    micro.Log('> close_tree('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id] or treepanes[pane_id]
    if conf then
        -- TODO: saved the list of closed items so that we can reuse it if we
        -- open the treeview again.
        if conf.tree_pane then
            treepanes[nvb_str(conf.tree_pane)] = nil
            conf.tree_pane:Quit()
            conf.tree_pane = nil
        end
        clear_messenger()
    end

    micro.Log('< close_tree')
end


-------------------------------------------------------------------------------
-- Shorthand functions for actions to reduce repeat code
-------------------------------------------------------------------------------

-- Move the cursor to the top, but don't allow the action
local function aftermove_if_tree(pane)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        if pane.Cursor.Loc.Y < 2 then
            -- If it went past the "..", move back onto it
            pane.Cursor:DownN(2 - pane.Cursor.Loc.Y)
        end
        select_line(pane)
    end
end

-- Used to fail certain actions that we shouldn't allow on the tree_view
local function false_if_tree(pane)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        return false
    end
end

-- Select the line at the cursor
local function selectline_if_tree(pane)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        select_line(pane, nil)
    end
end

local function clearselection_if_tree(pane)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        -- Clear the selection when doing a find, so it doesn't copy the current line
        pane.Cursor:ResetSelection()
    end
end

-------------------------------------------------------------------------------

-- Run while using ↑
function onCursorUp(pane)
    selectline_if_tree(pane)
end

-- Run while using ↓
function onCursorDown(pane)
    selectline_if_tree(pane)
end

-- Run while using PageUp
function onCursorPageUp(pane)
    aftermove_if_tree(pane)
end

-- Run while using Ctrl-Up
function onCursorStart(pane)
    aftermove_if_tree(pane)
end

-- Run while using PageDown
function onCursorPageDown(pane)
    selectline_if_tree(pane)
end

-- Run while using Ctrl-Down
function onCursorEnd(pane)
    selectline_if_tree(pane)
end

-- Run while opening a buffer panel (when micro already running)
function onBufferOpen(buf)
    micro.Log('> onBufferOpen('..buf_str(buf)..')')

    -- Note: it is very important to wait until init has started to run,
    -- because micro does some funny things with buffers at startup.
    if init_started then
        -- local tab_id = micro.GetTab():ID()
        -- pane_id = tab_id..':'..buf:GetName()
--
        -- local conf = mainpanes[pane_id]


        local main_pane = micro.CurPane()
        micro.Log('  CurPane: '..nvb_str(main_pane))
        micro.Log('  CurPane.Buf:GetName(): '..main_pane.Buf:GetName())
---[[
        -- Retrieve the FileType 'openonstart' option.
        local openonstart = get_option_among_list(buf, 'navbar.openonstart', {true, false}, false)

        -- micro.Log('  conf is ' .. tostring(conf))
        -- micro.Log('  buffer name = ' .. buf:GetName())
        -- micro.Log('  buffer ft = ' .. buf:FileType())
        micro.Log('  buffer openonstart = ' .. tostring(openonstart))

        -- need to disable until we can find a way to retrieve the view from a
        -- buffer.
        -- if openonstart then
            -- toggle_tree(nil)
        -- end
--]]

    end
    micro.Log('< onBufferOpen')
end

function onBufPaneOpen(pane)
    micro.Log('> onBufPaneOpen('..nvb_str(pane)..')')
    micro.Log('< onBufPaneOpen')
end

-- Run when closing the main buffer
function preQuit(pane)
    micro.Log('> preQuit('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id]
    if conf then
        micro.Log('  conf = '..tostring(conf))
        conf:closed_save()
        close_tree(pane)
    end

    micro.Log('< preQuit')
end

-- Run when closing all
function preQuitAll(pane)
    micro.Log('> preQuitAll('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id]
    if conf then
        close_tree(pane)
    end

    micro.Log('< preQuitAll')
end

-- Run when saving the buffer
function preSave(pane)
    micro.Log('> preSave('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        -- The treeview is read-only, so we should not be saving the treeview.
        return false
    end

    micro.Log('< preSave')
end

-- Run while saving the buffer.
function onSave(pane)
    micro.Log('> onSave('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id]

    if conf then
        local treeview = conf.tree_pane
        local last_y = treeview.Cursor.Loc.Y
        -- rebuild the content of the tree whenever we save the main buffer.
        refresh_structure(pane)
        refresh_view(pane)
        select_line(treeview, last_y)
    end
    micro.Log('< onSave')
end

--- Run while using the find command.
function onFind(pane)
    -- FIXME: doesn't work for whatever reason
    -- Select the whole line after a find, instead of just the input txt
    selectline_if_tree(pane)
end

--- Command to handle mouse press.
function MousePress(pane)
    micro.Log('> MousePress('..nvb_str(pane)..')')
    micro.Log('< MousePress')
end

--- Command to handle mouse press.
function onMousePress(pane)
    micro.Log('> onMousePress('..nvb_str(pane)..')')
    micro.Log('< onMousePress')
end

function preMousePress(pane, event)
    micro.Log('> preMousePress('..nvb_str(pane)..'/'..tostring(event)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        local x, y = event:Position()
        -- Fixes the y because softwrap messes with it
        local new_x, new_y = conf.treeview:GetMouseClickLocation(x, y)
        micro.Log('X Click')
        -- Try to open whatever is at the click's y index
        -- Will go into/back dirs based on what's clicked, nothing gets expanded
        -- try_open_at_y(new_y)
        -- Don't actually allow the mousepress to trigger, so we avoid highlighting stuff
        return false
    end

    micro.Log('< preMousePress')
end

--- Preprocess the find command
function preFind(pane)
    -- Since something is always selected, clear before a find
    -- Prevents copying the selection into the find input
    clearselection_if_tree(pane)
end

--- Preprocess the rune (key pressed) in a pane.
function preRune(pane, rune)
    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        local rune_toggle = config.GetGlobalOption("navbar.treeview_rune_toggle")
        local rune_goto  = config.GetGlobalOption("navbar.treeview_rune_goto")
        local rune_open_all  = config.GetGlobalOption("navbar.treeview_rune_open_all")
        local rune_close_all = config.GetGlobalOption("navbar.treeview_rune_close_all")

        if rune == rune_goto then
            nvb_goto_line(pane)
        elseif rune == rune_toggle then
            nvb_node_toggle(pane)
        elseif rune == rune_open_all then
            nvb_node_open_all(pane)
        elseif rune == rune_close_all then
            nvb_node_close_all(pane)
        end
        return false -- no need to process any further with other plugins.
    end
end

-------------------------------------------------------------------------------
-- NavBar Commands
-------------------------------------------------------------------------------

--- Command to jump in the main view to the item selected in the tree view.
function nvb_goto_line(pane)
    micro.Log('> nvb_goto_line('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]

    if conf then
        local last_y = pane.Cursor.Loc.Y
        local node = conf.node_list[last_y - 1]

        if node ~= false and node.line ~= -1 then
            local startline
            if node.line - 2 < 0 then
                startline = 0
            else
                startline = node.line - 2
            end
            conf.main_pane:GetView().StartLine = startline
            conf.main_pane.Cursor.Loc.Y = node.line - 1
            -- Center() doesn't work for us, we need to do our own
            -- conf.main_pane:Center()
            conf.main_pane.Cursor:SelectLine()
            selectline_if_tree(pane)
        end
    end

    micro.Log('< nvb_goto_line')
end

--- Command to open all previously closed nodes in our tree view.
function nvb_node_open_all(pane)
    micro.Log('> nvb_node_open_all('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]
    if conf then
        local last_y = pane.Cursor.Loc.Y
        local view = pane:GetView()
        local startline = view.StartLine
        micro.Log('X last_y = '..tostring(last_y))
        micro.Log('X startline = '..tostring(startline))

        micro.Log("  conf.closed := {}")
        conf.closed = {}
        refresh_view(pane)
        -- Reset the view
        last_y = 2
        view.StartLine = 0
        select_line(pane, last_y)
    end

    micro.Log('< nvb_node_open_all')
end

--- Command to close all node with visible children in our tree view.
function nvb_node_close_all(pane)
    micro.Log('> nvb_node_close_all('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]
    if conf then
        local last_y = pane.Cursor.Loc.Y
        micro.Log('X last_y='..tostring(last_y))

        for _, node in ipairs(conf.node_list) do
            -- Note: we have inserted boolean (false) in the list of nodes
            -- for the blank lines.
            if node then
                if not gen.is_empty(node:get_children()) then
                    local abs_label = node:get_abs_label()
                    micro.Log("  conf.closed += '"..abs_label.."'")
                    conf.closed[abs_label] = true
                end
            end
        end
        local view = pane:GetView()
        refresh_view(pane)
        -- Reset the view
        last_y = 2
        view.StartLine = 0
        select_line(pane, last_y)
    end

    micro.Log('< nvb_node_close_all')
end

--- Command to toggle a node between closed and open
function nvb_node_toggle(pane)
    micro.Log('> toggle_node('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = treepanes[pane_id]
    if conf then
        local last_y = pane.Cursor.Loc.Y
        micro.Log('X last_y='..tostring(last_y))
        local node = conf.node_list[last_y - 1]

        if node then
            local abs_label = node:get_abs_label()
            if not conf.closed[abs_label] then
                micro.Log("  conf.closed += '"..abs_label.."'")
                conf.closed[abs_label] = true
            else
                micro.Log("  conf.closed -= '"..abs_label.."'")
                conf.closed[abs_label] = nil
            end
            local view = pane:GetView()
            local startline = view.StartLine
            refresh_view(pane)
            view.StartLine = startline
            select_line(pane, last_y)
        end
    end

    micro.Log('< toggle_node')
end

--- Command to toggle the side bar with our tree view.
function toggle_tree(pane)
    micro.Log('> toggle_tree('..nvb_str(pane)..')')

    local pane_id = nvb_str(pane)
    local conf = mainpanes[pane_id] or treepanes[pane_id]
    if not conf or (conf and (conf.tree_pane == nil)) then
        pane = pane or micro.CurPane()
        open_tree(pane)
    else
        pane = conf.main_pane
        close_tree(pane)
    end

    micro.Log('< toggle_tree')
end

-------------------------------------------------------------------------------

--- Initialize the navbar plugin.
function init()
    micro.Log('> init')
    micro.Log('  nvb_path = '..NVB_PATH)
    micro.Log('  usr_local_share = '..usr_local_share)

    init_started = true

    languages_supported = get_languages_supported()


    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.AddRuntimeFile("navbar", config.RTSyntax, "syntax.yaml")

    config.TryBindKey("Alt-n", "lua:navbar.toggle_tree", false)

    -- Lets the user have the filetree auto-open any time Micro is opened
    -- false by default, as it's a rather noticable user-facing change
    config.RegisterCommonOption("navbar", "openonstart", false)
    config.RegisterCommonOption("navbar", "treestyle", "bare")
    config.RegisterCommonOption("navbar", "treestyle_spacing", 0)
    config.RegisterCommonOption("navbar", "softwrap", false)
    config.RegisterCommonOption("navbar", "persistent", false)
    config.RegisterCommonOption("navbar", "treeview_size", 25)
    config.RegisterCommonOption("navbar", "treeview_rune_toggle", ' ')
    config.RegisterCommonOption("navbar", "treeview_rune_open_all", 'o')
    config.RegisterCommonOption("navbar", "treeview_rune_close_all", 'c')
    config.RegisterCommonOption("navbar", "treeview_rune_goto", 'g')

    -- Open/close the tree view
    config.MakeCommand("navbar", toggle_tree, config.NoComplete)
    -- Goto corresponding line
    config.MakeCommand("nvb_goto", nvb_goto_line, config.NoComplete)
    -- Toggle a node between closed and open state
    config.MakeCommand("nvb_toggle", nvb_node_toggle, config.NoComplete)
    -- Close all open nodes
    config.MakeCommand("nvb_close_all", nvb_node_close_all, config.NoComplete)
    -- Open all closed nodes
    config.MakeCommand("nvb_open_all", nvb_node_open_all, config.NoComplete)

    -- NOTE: This must be below the syntax load command or coloring won't work
    -- Just auto-open if the option is enabled
    -- This will run when the plugin first loads
    local main_pane = micro.CurPane()
    local main_id = nvb_str(main_pane)
    local open_on_start = get_option_among_list(main_pane.Buf, 'navbar.openonstart', {true, false}, false)
    if open_on_start then
        local conf = mainpanes[main_id]
        -- Check for safety on the off-chance someone's init.lua breaks this
        if not conf then
            open_tree(main_pane)
            -- Puts the cursor back in the empty view that initially spawns
            -- This is so the cursor isn't sitting in the tree view at startup
            -- main_pane:NextSplit()
        else
            -- Log error so they can fix it
            micro.Log("Warning: navbar.openonstart was enabled, but somehow the tree was already open so the option was ignored.")
        end
    end
    micro.Log('< init')
end
