VERSION = "0.0.1"

local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")
local buffer = import("micro/buffer")

package.path = "navbar/?.lua;" .. package.path

local gen = require('generic')
local lgp = require('lang_python')

local DISPLAY_NAME = 'navbar'

-- Holds the micro.CurPane() we're manipulating
local tree_view = nil


-- Clear out all stuff in Micro's messenger
local function clear_messenger()
    -- messenger:Reset()
	-- messenger:Clear()
end

local function display_content(buf)
    local ret = {}
    local ttype = config.GetGlobalOption("navbar.treestyle")

    if not gen.is_in(ttype, {'bare', 'ascii', 'box'}) then
        ttype = 'bare' -- pick a default mode
    end

    local bytes = util.String(buf:Bytes())
    local struc = lgp.export_structure_python(bytes)
    local ttree = lgp.tree_to_navbar(struc)
    for k, v in ipairs(ttree) do
        ret[#ret+1] = v:tree(ttype, 0) .. '\n\n'
    end

    return table.concat(ret)
end

local function refresh_view(buf)
    clear_messenger()

    -- Delete everything
	tree_view.Buf.EventHandler:Remove(tree_view.Buf:Start(), tree_view.Buf:End())

	local ft = buf:FileType()
	local fn = buf:GetName()

	tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 0), 'Symbols\n\n')

    -- There seems to be a bug in micro FileType automatic recognition.
    if     (ft == 'python') or ((ft == '') and (fn:ends_with('.py'))) then
        local msg = display_content(buf)
        tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 2), msg)

    elseif (ft == 'lua') or ((ft == '') and (fn:ends_with('.lua'))) then
        local msg = 'Hopefully soon.\n'
        tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 2), msg)

    else
        local msg = 'Only python and lua\n(partially) are supported\nat the moment.\n'
        tree_view.Buf.EventHandler:Insert(buffer.Loc(0, 2), msg)
    end

    tree_view:Tab():Resize()
end

-- open_tree setup's the view
local function open_tree()
    -- Retrieve the current buffer
    local buf = micro.CurPane().Buf

	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer("", DISPLAY_NAME), false)
	-- Save the new view so we can access it later
	tree_view = micro.CurPane()

	-- Set the width of tree_view to 30% & lock it
    tree_view:ResizePane(30)
	-- Set the type to unsavable
    -- tree_view.Buf.Type = buffer.BTLog
    tree_view.Buf.Type.Scratch = true
    tree_view.Buf.Type.Readonly = true

	-- Set the various display settings, but only on our view (by using SetLocalOption instead of SetOption)
	-- NOTE: Micro requires the true/false to be a string
	-- Softwrap long strings (the file/dir paths)
    tree_view.Buf:SetOptionNative("softwrap", true)
    -- No line numbering
    tree_view.Buf:SetOptionNative("ruler", false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    tree_view.Buf:SetOptionNative("autosave", false)
    -- Don't show the statusline to differentiate the view from normal views
    tree_view.Buf:SetOptionNative("statusformatr", "")
    tree_view.Buf:SetOptionNative("statusformatl", DISPLAY_NAME)
    tree_view.Buf:SetOptionNative("scrollbar", false)

    -- Display the content
    refresh_view(buf)
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

    -- Open/close the tree view
    config.MakeCommand("navbar", toggle_tree, config.NoComplete)
    -- Rename the file/dir under the cursor

    -- NOTE: This must be below the syntax load command or coloring won't work
    -- Just auto-open if the option is enabled
    -- This will run when the plugin first loads
    if config.GetGlobalOption("navbar.openonstart") then
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

