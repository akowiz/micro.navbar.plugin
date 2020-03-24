--- @module navbar

VERSION = "0.0.1"

local nvb_path = "navbar/?.lua;"
if not string.find(package.path, "navbar") then
    package.path = nvb_path .. package.path
end


local micro  = import("micro")
local config = import("micro/config")
local util   = import("micro/util")
local buffer = import("micro/buffer")


local gen = require('generic')
local lgp = require('lang_python')
local lgl = require('lang_lua')

local DISPLAY_NAME = 'navbar'
local SIZE_MIN = 15


local conf = nil
local init_started = false

-------------------------------------------------------------------------------

--- NavBufConf hold our configuration for the current buffer
-- type NavBufConf
local NavBufConf = gen.class()

function NavBufConf:__init(main)
    micro.Log('> NavBufConf:__init('..tostring(main)..')')

    self.main_view = main or nil
    self.tree_view = nil
    self.root = nil
    self.node_list = nil
    self.closed = {}
    self.language = nil

    if (self.main_view ~= nil) then
        self.language = self.main_view.Buf:FileType()
    end

    micro.Log('< NavBufConf.__init')
end

--- Display the configuration in a string.
function NavBufConf:__tostring()
    ret = {}
    table.insert(ret, 'main_view: '..tostring(self.main_view))
    table.insert(ret, 'tree_view: '..tostring(self.tree_view))
    table.insert(ret, 'language:  '..tostring(self.language))
    table.insert(ret, 'closed:    '..gen.set_tostring(self.closed))
    ret = table.concat(ret, ', ')
    return ret
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
    micro.Log('> get_option_among_list(buf='..tostring(buf)..' name='..name..' default='..tostring(default)..')')
    local current = config.GetGlobalOption(name)
    micro.Log('  global option='..tostring(current))
    if (buf ~= nil) then
        local local_option = buf.Settings[name]
        micro.Log('  local option='..tostring(local_option))
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
    micro.Log('> get_option_among_range(buf='..tostring(buf)..' name='..name..' lower='..tostring(lower)..' upper='..tostring(upper)..')')
    local current = config.GetGlobalOption(name)
    micro.Log('  global option='..tostring(current))
    if (buf ~= nil) and (buf.Settings ~= nil) then
        local local_option = buf.Settings[name]
        if local_option then
            micro.Log('  buffer option='..tostring(local_option))
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
local function select_line(pane, last_y)
    pane = pane or conf.tree_view

    if pane == conf.tree_view then
        -- Make last_y optional
        if last_y ~= nil then
            -- Don't let them move past the 2 first lines
            if last_y > 1 then
                -- If the last position was valid, move back to it
                pane.Cursor.Loc.Y = last_y
            end
        elseif pane.Cursor.Loc.Y < 2 then
            -- Put the cursor on the 1st item
            pane.Cursor.Loc.Y = 2
        end
    else
        last_y = last_y or 0
    end

    -- Puts the cursor back in bounds (if it isn't) for safety
    pane.Cursor:Relocate()

    -- Makes sure the cursor is visible (if it isn't)
    -- (false) means no callback
    pane:Center()

    -- Highlight the current line where the cursor is
    pane.Cursor:SelectLine()
end

-- Moves the cursor to the top in tree_view
local function move_cursor_top(pane)
    pane = pane or conf.tree_view

    -- line to go to
    if pane == conf.tree_view then
        pane.Cursor.Loc.Y = 2
    else
        pane.Cursor.Loc.Y = 0
    end

    -- select the line after moving
    select_line(pane)
end


local function refresh_structure()
    micro.Log('> refresh_structure()')

    if not conf.language then
        micro.InfoBar():Error(DISPLAY_NAME .. ": Only python and lua languages are currently supported.")
        return
    end

    local bytes = util.String(conf.main_view.Buf:Bytes())

    conf.root = nil
    if     conf.language == 'python' then
        conf.root = lgp.export_structure(bytes)
    elseif conf.language == 'lua' then
        conf.root = lgl.export_structure(bytes)
    end
    micro.Log('< refresh_structure()')
end

--- Return the content (string) of the tree view to be displayed.
local function display_content()
    micro.Log('> display_content()')
    local buf = conf.main_view.Buf
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

local function refresh_view()
    micro.Log('> refresh_view()')
    clear_messenger()

    local content = display_content()

    -- delete everything in the tree_view
    conf.tree_view.Buf.EventHandler:Remove(
        conf.tree_view.Buf:Start(),
        conf.tree_view.Buf:End())

    -- display a new tree_view
    conf.tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 0), 'Symbols\n\n')
    conf.tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 2), content)
    conf.tree_view:Tab():Resize()

    micro.Log('< refresh_view')
end

--- Helper function to open a side panel with our navigation bar.
local function open_tree(pane)
    micro.Log('> nvb_open_tree('..pane.Buf:GetName()..'/'..tostring(pane)..')')
    local main_view = pane

    conf = NavBufConf(main_view)

    micro.Log('  conf: '..tostring(conf))

    if not conf.language then
        micro.InfoBar():Error(DISPLAY_NAME .. ": Only python and lua languages are currently supported.")
        return
    end

    -- Open a new Vsplit (on the very left)
    pane:VSplitIndex(buffer.NewBuffer("", DISPLAY_NAME), false)

    -- Save the new view so we can access it later
    conf.tree_view = micro.CurPane()

    -- Set the width of tree_view (in characters)
    local size = get_option_among_range(main_view.Buf, 'navbar.treeview_size', SIZE_MIN)
    conf.tree_view:ResizePane(size)

    -- Set the type to unsavable
    -- tree_view.Buf.Type = buffer.BTLog
    conf.tree_view.Buf.Type.Scratch = true
    conf.tree_view.Buf.Type.Readonly = true

    -- Set the various display settings, but only on our view (by using
    -- SetLocalOption instead of SetOption)

    -- Set the softwrap value for treeview
    local sw = get_option_among_list(main_view.Buf, 'navbar.softwrap', {true, false}, false)
    conf.tree_view.Buf:SetOptionNative("softwrap", sw)

    -- No line numbering
    conf.tree_view.Buf:SetOptionNative("ruler", false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    conf.tree_view.Buf:SetOptionNative("autosave", false)
    -- Don't show the statusline to differentiate the view from normal views
    conf.tree_view.Buf:SetOptionNative("statusformatr", "")
    conf.tree_view.Buf:SetOptionNative("statusformatl", DISPLAY_NAME)
    conf.tree_view.Buf:SetOptionNative("scrollbar", false)

    -- Display the content
    refresh_structure()
    refresh_view(conf.main_view.Buf)

    -- Move the cursor
    move_cursor_top(conf.tree_view)

    micro.Log('< nvb_open_tree')
end

--- Helper function to close the side panel containing our navigation bar.
local function close_tree(pane)
    micro.Log('> nvb_close_tree('..tostring(pane)..')')
    if (conf ~= nil)  and (conf.tree_view ~= nil) then
        -- TODO: saved the list of closed items so that we can reuse it if we
        -- open the treeview again.
        conf.tree_view:Quit()
        conf.tree_view = nil
        clear_messenger()
    end
    micro.Log('< nvb_close_tree')
end


-------------------------------------------------------------------------------
-- Shorthand functions for actions to reduce repeat code
-------------------------------------------------------------------------------

-- Move the cursor to the top, but don't allow the action
local function aftermove_if_tree(pane)
    if (conf ~= nil) and (pane == conf.tree_view) then
        if pane.Cursor.Loc.Y < 2 then
            -- If it went past the "..", move back onto it
            pane.Cursor:DownN(2 - pane.Cursor.Loc.Y)
        end
        select_line(pane)
    end
end

-- Used to fail certain actions that we shouldn't allow on the tree_view
local function false_if_tree(pane)
    if (conf ~= nil) and (pane == conf.tree_view) then
        return false
    end
end

-- Select the line at the cursor
local function selectline_if_tree(pane)
    if (conf ~= nil) and (pane == conf.tree_view) then
        select_line(pane)
    end
end

local function clearselection_if_tree(pane)
    if (conf ~= nil) and (pane == conf.tree_view) then
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
    micro.Log('> onBufferOpen('..buf:GetName()..'/'..tostring(buf)..')')
--[[
    -- Note: it is very important to wait until init has started to run,
    -- because micro does some funny things with buffers at startup.
    if init_started then

        -- Retrieve the FileType 'openonstart' option.
        local openonstart = get_option_among_list(buf, 'navbar.openonstart', {true, false}, false)

        micro.Log('  conf is ' .. tostring(conf))
        micro.Log('  buffer name = ' .. buf:GetName())
        micro.Log('  buffer ft = ' .. buf:FileType())
        micro.Log('  buffer openonstart = ' .. tostring(openonstart))

        if (conf == nil) and openonstart then
            toggle_tree()
        end

    end
--]]
    micro.Log('< onBufferOpen')
end

function onBufPaneOpen(pane)
    micro.Log('> onBufPaneOpen('..pane.Buf:GetName()..'/'..tostring(pane)..')')
    micro.Log('< onBufPaneOpen')
end

-- Run when closing the main buffer
function preQuit(pane)
    micro.Log('> preQuit('..pane.Buf:GetName()..'/'..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.main_view) then
        close_tree(pane)
    end
    micro.Log('< preQuit')
end

-- Run when closing all
function preQuitAll(pane)
    micro.Log('> preQuitAll('..pane.Buf:GetName()..'/'..tostring(pane)..')')
    if (conf ~= nil) then
        close_tree(pane)
    end
    micro.Log('< preQuitAll')
end

-- Run while saving the buffer.
function onSave(pane)
    micro.Log('> onSave('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.main_view) then
        -- rebuild the content of the tree whenever we save the main buffer.
        refresh_structure()
        refresh_view()
    end
    micro.Log('< onSave')
end

--- Run while using the find command.
function onFind(pane)
    -- FIXME: doesn't work for whatever reason
    -- Select the whole line after a find, instead of just the input txt
    selectline_if_tree(pane)
end


--- Preprocess the find command
function preFind(pane)
    -- Since something is always selected, clear before a find
    -- Prevents copying the selection into the find input
    clearselection_if_tree(pane)
end

--- Preprocess the rune (key pressed) in a pane.
function preRune(pane, rune)
    if (conf ~= nil) and (pane == conf.tree_view) then

        local rune_open  = config.GetGlobalOption("navbar.treeview_rune_open")
        local rune_close = config.GetGlobalOption("navbar.treeview_rune_close")
        local rune_goto  = config.GetGlobalOption("navbar.treeview_rune_goto")
        local rune_open_all  = config.GetGlobalOption("navbar.treeview_rune_open_all")
        local rune_close_all = config.GetGlobalOption("navbar.treeview_rune_close_all")

        if rune == rune_goto then
            nvb_goto_line(pane)
        elseif rune == rune_open then
            nvb_node_open(pane)
        elseif rune == rune_open_all then
            nvb_node_open_all(pane)
        elseif rune == rune_close then
            nvb_node_close(pane)
        elseif rune == rune_close_all then
            nvb_node_close_all(pane)
        end
        return false -- no need to process any further with other plugins.
    end
end

-------------------------------------------------------------------------------
-- NavBar Commands
-------------------------------------------------------------------------------

--- Helper dummy function for debuging purpose
local function local_do_nothing()
    micro.Log('> local_do_nothing()')
    micro.Log('< local_do_nothing')
end

--- Dummy Command for debugging purpose
function global_do_nothing(pane)
    micro.Log('> global_do_nothing()')
    micro.Log('< global_do_nothing')
end

--- Command to jump in the main view to the item selected in the tree view.
function nvb_goto_line(pane)
    micro.Log('> nvb_goto_line('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.tree_view) then
        local last_y = pane.Cursor.Loc.Y
        local node = conf.node_list[last_y - 1]

        if node ~= false and node.line ~= -1 then
            conf.main_view.Cursor.Loc.Y = node.line - 1
            conf.main_view.Cursor:Relocate()
            conf.main_view:Center()
            conf.main_view.Cursor:SelectLine()
            select_line(pane, last_y)
        end
    end
    micro.Log('< nvb_goto_line')
end

--- Command to open a previously closed node in our tree view.
function nvb_node_open(pane)
    micro.Log('> nvb_node_open('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.tree_view) then
        local last_y = pane.Cursor.Loc.Y
        local node = conf.node_list[last_y - 1]

        if node ~= false then
            local abs_label = node:get_abs_label()
            if conf.closed[abs_label] then
                conf.closed[abs_label] = nil
                refresh_view()
                select_line(pane, last_y)
            end
        end
    end
    micro.Log('< nvb_node_open')
end

--- Command to open all previously closed nodes in our tree view.
function nvb_node_open_all(pane)
    micro.Log('> nvb_node_open_all('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.tree_view) then
        local last_y = 2
        conf.closed = {}
        refresh_view()
        select_line(pane, last_y)
    end
    micro.Log('< nvb_node_open_all')
end

--- Command to close a node with visible children in our tree view.
function nvb_node_close(pane)
    micro.Log('> nvb_node_close('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.tree_view) then
        local last_y = pane.Cursor.Loc.Y
        local node = conf.node_list[last_y - 1]

        if node ~= false then
            local abs_label = node:get_abs_label()
            if not conf.closed[abs_label] then
                conf.closed[abs_label] = true
                refresh_view()
                select_line(pane, last_y)
            end
        end
    end
    micro.Log('< nvb_node_close')
end

--- Command to close all node with visible children in our tree view.
function nvb_node_close_all(pane)
    micro.Log('> nvb_node_close_all('..tostring(pane)..')')
    if (conf ~= nil) and (pane == conf.tree_view) then
        local last_y = pane.Cursor.Loc.Y

        for _, node in ipairs(conf.node_list) do
            -- Note: we have inserted boolean (false) in the list of nodes
            -- for the blank lines.
            if node then
                if not gen.is_empty(node:get_children()) then
                    local abs_label = node:get_abs_label()
                    conf.closed[abs_label] = true
                end
            end
        end
        refresh_view()
        select_line(pane, last_y)
    end
    micro.Log('< nvb_node_close_all')
end

--- Command to toggle the side bar with our tree view.
function toggle_tree()
    micro.Log('> toggle_tree')
    local pane
    if (conf == nil) or ((conf ~= nil) and (conf.tree_view == nil)) then
        pane = micro.CurPane()
        open_tree(pane)
    else
        pane = conf.main_view
        close_tree(pane)
    end
    micro.Log('< toggle_tree')
end

-------------------------------------------------------------------------------

--- Initialize the navbar plugin.
function init()
    micro.Log('> init')
    init_started = true
    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.TryBindKey("Alt-n", "lua:navbar.toggle_tree", false)

    -- Lets the user have the filetree auto-open any time Micro is opened
    -- false by default, as it's a rather noticable user-facing change
    config.RegisterCommonOption("navbar", "openonstart", false)
    config.RegisterCommonOption("navbar", "treestyle", "bare")
    config.RegisterCommonOption("navbar", "treestyle_spacing", 0)
    config.RegisterCommonOption("navbar", "softwrap", false)
    config.RegisterCommonOption("navbar", "treeview_size", 25)
    config.RegisterCommonOption("navbar", "treeview_rune_open", '+')
    config.RegisterCommonOption("navbar", "treeview_rune_open_all", 'o')
    config.RegisterCommonOption("navbar", "treeview_rune_close", '-')
    config.RegisterCommonOption("navbar", "treeview_rune_close_all", 'c')
    config.RegisterCommonOption("navbar", "treeview_rune_goto", ' ')

    -- Open/close the tree view
    config.MakeCommand("navbar", toggle_tree, config.NoComplete)
    -- Goto corresponding line
    config.MakeCommand("nvb_goto", nvb_goto_line, config.NoComplete)
    -- Close an open node
    config.MakeCommand("nvb_close", nvb_node_close, config.NoComplete)
    -- Close all open nodes
    config.MakeCommand("nvb_close_all", nvb_node_close_all, config.NoComplete)
    -- Open a closed node
    config.MakeCommand("nvb_open", nvb_node_open, config.NoComplete)
    -- Open all closed nodes
    config.MakeCommand("nvb_open_all", nvb_node_open_all, config.NoComplete)

    -- NOTE: This must be below the syntax load command or coloring won't work
    -- Just auto-open if the option is enabled
    -- This will run when the plugin first loads
    local main_view = micro.CurPane()
    local open_on_start = get_option_among_list(main_view.Buf, 'navbar.openonstart', {true, false}, false)
    if open_on_start then
        -- Check for safety on the off-chance someone's init.lua breaks this
        if (conf == nil) then
            open_tree(main_view)
            -- Puts the cursor back in the empty view that initially spawns
            -- This is so the cursor isn't sitting in the tree view at startup
            -- main_view:NextSplit()
        else
            -- Log error so they can fix it
            micro.Log("Warning: navbar.openonstart was enabled, but somehow the tree was already open so the option was ignored.")
        end
    end
    micro.Log('< init')
end
