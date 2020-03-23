VERSION = "0.0.1"

local nvb_path = "navbar/?.lua;"
if not string.find(package.path, "navbar") then
    package.path = nvb_path .. package.path
end


local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")
local buffer = import("micro/buffer")


local gen = require('generic')
local lgp = require('lang_python')
local lgl = require('lang_lua')

local DISPLAY_NAME = 'navbar'
local SIZE_MIN = 15


-- Holds the micro.CurPane() we're manipulating
local main_view = nil -- The original panel
local tree_view = nil -- The navbar panel
local node_list = nil

-- Holds the views for the multiple panes we are manipulating
local tree_views = {}



--- Retrieve the global option, validate it against a list and provide default if value is not in list.
-- @tparam string name Name of the global option.
-- @tparam values table Table of valid values.
-- @param default Default value to use if the current option is not in values (must be in values).
-- @return A valid option.
function get_option_among_list(name, values, default)
    default = default or values[1]
    local current = config.GetGlobalOption(name)
    if current then
        if not gen.is_in(current, values) then
            if gen.is_in(default, values) then
                current = default
            else
                error('Default value ' .. default .. " for '" .. name .. "' is not in the list of valid values.")
            end
        end
    end
    return current
end

--- Retrieve the global option, validate it against a min and max, provide default if value is not in range.
-- @tparam string name Name of the global option.
-- @tparam int lower Minimum value or nil if there is no minimum.
-- @tparam int upper Maximum value or nil if there is no maximum.
-- @treturn int A valid option.
function get_option_among_range(name, lower, upper)
    local current = config.GetGlobalOption(name)
    if current then
        if     lower and (current < lower) then
            current = lower
        elseif upper and (current > upper) then
            current = upper
        end
    end
    return current
end



-- Clear out all stuff in Micro's messenger
local function clear_messenger()
    micro.InfoBar():Reset()
    -- messenger:Reset()
    -- messenger:Clear()
end

local function display_content(buf, language)
    local ret = {}
    local ttype  = get_option_among_list("navbar.treestyle", {'bare', 'ascii', 'box'})
    local tspace = get_option_among_range("navbar.treestyle_spacing", 0, nil)

    local bytes = util.String(buf:Bytes())
    local struc
    local tl_list

    if     language == 'python' then
        struc   = lgp.export_structure(bytes)
        tl_list = lgp.tree_to_navbar(struc, ttype, tspace)
    elseif language == 'lua' then
        struc   = lgl.export_structure(bytes)
        tl_list = lgl.tree_to_navbar(struc, ttype, tspace)
    else
        struc = nil
    end

    local display_text = {}

    node_list = {}
    for _, tl in ipairs(tl_list) do
        display_text[#display_text+1] = tostring(tl)
        if tl.node ~= nil then
            node_list[#node_list+1] = tl.node
        else
            node_list[#node_list+1] = false
        end
    end

    return table.concat(display_text, '\n')
end

local function refresh_view(buf)
    clear_messenger()

    -- Delete everything
    tree_view.Buf.EventHandler:Remove(tree_view.Buf:Start(), tree_view.Buf:End())

    local ft = buf:FileType()
    local fn = buf:GetName()
    local content = ''

    tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 0), 'Symbols\n\n')

    -- There seems to be a bug in micro FileType automatic recognition.
    if     (ft == 'python') or ((ft == '') and (fn:ends_with('.py'))) then
        content = display_content(buf, 'python')

    elseif (ft == 'lua') or ((ft == '') and (fn:ends_with('.lua'))) then
        content = display_content(buf, 'lua')

    else
        micro.InfoBar():Error(DISPLAY_NAME .. ": Only python and lua languages are currently supported.")
    end

    tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 2), content)
    tree_view:Tab():Resize()
end

-- Hightlights the line when you move the cursor up/down
local function select_line(pane, last_y)
    pane = pane or tree_view

    if pane == tree_view then
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


-- Moves the cursor to the ".." in tree_view
local function move_cursor_top(pane)
    pane = pane or tree_view

    -- line to go to
    if pane == tree_view then
        pane.Cursor.Loc.Y = 2
    else
        pane.Cursor.Loc.Y = 0
    end

    -- select the line after moving
    select_line(pane)
end

-- Move the cursor to the top, but don't allow the action
local function aftermove_if_tree(view)
    if view == tree_view then
        if view.Cursor.Loc.Y < 2 then
            -- If it went past the "..", move back onto it
            view.Cursor:DownN(2 - view.Cursor.Loc.Y)
        end
        select_line(view)
    end
end

-- Used to fail certain actions that we shouldn't allow on the tree_view
local function false_if_tree(view)
    if view == tree_view then
        return false
    end
end

-- Select the line at the cursor
local function selectline_if_tree(view)
    if view == tree_view then
        select_line(view)
    end
end

local function clearselection_if_tree(view)
    if view == tree_view then
        -- Clear the selection when doing a find, so it doesn't copy the current line
        view.Cursor:ResetSelection()
    end
end

function onCursorUp(view)
    selectline_if_tree(view)
end

function onCursorDown(view)
    selectline_if_tree(view)
end

-- PageUp
function onCursorPageUp(view)
    aftermove_if_tree(view)
end

-- Ctrl-Up
function onCursorStart(view)
    aftermove_if_tree(view)
end

-- PageDown
function onCursorPageDown(view)
    selectline_if_tree(view)
end

-- Ctrl-Down
function onCursorEnd(view)
    selectline_if_tree(view)
end

function preFind(view)
    -- Since something is always selected, clear before a find
    -- Prevents copying the selection into the find input
    clearselection_if_tree(view)
end

function preRune(view, rune)
    local rune_open = config.GetGlobalOption("navbar.treeview_rune_open")
    local rune_close = config.GetGlobalOption("navbar.treeview_rune_close")
    local rune_goto = config.GetGlobalOption("navbar.treeview_rune_goto")

    if view ~= tree_view then
        return
    else
        if rune == rune_open then
            nvb_node_open()
        elseif rune == rune_close then
            nvb_node_close()
        elseif rune == rune_goto then
            nvb_goto_line()
        end
        return false
    end
end

-- FIXME: doesn't work for whatever reason
function onFind(view)
    -- Select the whole line after a find, instead of just the input txt
    selectline_if_tree(view)
end

function nvb_goto_line()
    if tree_view ~= nil and (micro.CurPane() == tree_view) then
        local tree_line
        local node
        -- Retrieve the line number to jump to
        tree_line = tree_view.Cursor.Loc.Y - 1
        node = node_list[tree_line]

        if node ~= false and node.line ~= -1 then
            main_view.Cursor.Loc.Y = node.line - 1
            main_view.Cursor:Relocate()
            main_view:Center()
            main_view.Cursor:SelectLine()
        end
    end
end

function nvb_node_open()
    -- FIXME: When the view is refresh, this will be lost!
    -- We need to remember the closed status independantly from the building
    -- of the list, and apply it after the list has been rebuilt.
    -- We also might want a function to refresh the list without rebuilding
    -- it fully.
    -- We don't want to loose the closed status whenever we add/remove items
    -- in our source file.
    -- we might also want to have persistant saving between sessions.
    if tree_view ~= nil and (micro.CurPane() == tree_view) then
        local tree_line
        local node
        tree_line = tree_view.Cursor.Loc.Y - 1
        node = node_list[tree_line]

        if node ~= false and node:is_closed() then
            node.closed = true
            refresh_view()
        end
    end
end

function nvb_node_close()
    -- FIXME: When the view is refresh, this will be lost!
    if tree_view ~= nil and (micro.CurPane() == tree_view) then
        local tree_line
        local node
        tree_line = tree_view.Cursor.Loc.Y - 1
        node = node_list[tree_line]

        if node ~= false and not node:is_closed() then
            node.closed = false
            refresh_view()
        end
    end
end

-- open_tree setup's the view
local function open_tree()
    -- Save the current panel so that we can use it later
    main_view = micro.CurPane()

    -- Open a new Vsplit (on the very left)
    micro.CurPane():VSplitIndex(buffer.NewBuffer("", DISPLAY_NAME), false)
    -- Save the new view so we can access it later
    tree_view = micro.CurPane()

    -- Set the width of tree_view (in characters)
    local size = get_option_among_range('navbar.treeview_size', SIZE_MIN)
    tree_view:ResizePane(size)

    -- Set the type to unsavable
    -- tree_view.Buf.Type = buffer.BTLog
    tree_view.Buf.Type.Scratch = true
    tree_view.Buf.Type.Readonly = true

    -- Set the various display settings, but only on our view (by using
    -- SetLocalOption instead of SetOption)

    -- Set the softwrap value for treeview
    local sw = get_option_among_list('navbar.softwrap', {true, false}, false)
    tree_view.Buf:SetOptionNative("softwrap", sw)

    -- No line numbering
    tree_view.Buf:SetOptionNative("ruler", false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    tree_view.Buf:SetOptionNative("autosave", false)
    -- Don't show the statusline to differentiate the view from normal views
    tree_view.Buf:SetOptionNative("statusformatr", "")
    tree_view.Buf:SetOptionNative("statusformatl", DISPLAY_NAME)
    tree_view.Buf:SetOptionNative("scrollbar", false)

    -- Display the content
    refresh_view(main_view.Buf)

    -- Move the cursor
    move_cursor_top(tree_view)
end

-- close_tree will close the tree plugin view and release memory.
local function close_tree()
    if tree_view ~= nil then
        tree_view:Quit()
        tree_view = nil
        clear_messenger()
    end
end

-- toggle_tree will toggle the tree view visible (create) and hide (delete).
function toggle_tree()
    if tree_view == nil then
        open_tree()
    else
        close_tree()
    end
end

--- Initialize the navbar plugin.
function init()
    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.TryBindKey("F5", "lua:navbar.toggle_tree", false)
    config.TryBindKey("Alt-n", "lua:navbar.toggle_tree", false)

    -- Lets the user have the filetree auto-open any time Micro is opened
    -- false by default, as it's a rather noticable user-facing change
    config.RegisterCommonOption("navbar", "openonstart", false)
    config.RegisterCommonOption("navbar", "treestyle", "bare")
    config.RegisterCommonOption("navbar", "treestyle_spacing", 0)
    config.RegisterCommonOption("navbar", "softwrap", false)
    config.RegisterCommonOption("navbar", "treeview_size", 25)
    config.RegisterCommonOption("navbar", "treeview_rune_open", '+')
    config.RegisterCommonOption("navbar", "treeview_rune_close", '-')
    config.RegisterCommonOption("navbar", "treeview_rune_goto", ' ')

    -- Open/close the tree view
    config.MakeCommand("navbar", toggle_tree, config.NoComplete)
    -- Goto corresponding line
    config.MakeCommand("nvb_goto", nvb_goto_line, config.NoComplete)
    -- Close an open node
    config.MakeCommand("nvb_close", nvb_node_close, config.NoComplete)
    -- Open a closed node
    config.MakeCommand("nvb_open", nvb_node_open, config.NoComplete)

    -- NOTE: This must be below the syntax load command or coloring won't work
    -- Just auto-open if the option is enabled
    -- This will run when the plugin first loads
    local open_on_start = get_option_among_list('navbar.openonstart', {true, false}, false)
    if open_on_start then
        -- Check for safety on the off-chance someone's init.lua breaks this
        if tree_view == nil then
            open_tree()
            -- Puts the cursor back in the empty view that initially spawns
            -- This is so the cursor isn't sitting in the tree view at startup
            micro.CurPane():NextSplit()
        else
            -- Log error so they can fix it
            micro.Log("Warning: navbar.openonstart was enabled, but somehow the tree was already open so the option was ignored.")
        end
    end
end

--- Refresh the content of the tree whenever we save the original buffer.
-- @tparam bufpane bp The buffer panel object.
-- @treturn bool false
function onSave(bp)
    if tree_view ~= nil then
        refresh_view(bp.Buf)
    end
    return false
end

