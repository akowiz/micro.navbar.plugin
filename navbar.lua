VERSION = "0.0.1"

local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")
local buffer = import("micro/buffer")

-- Holds the micro.CurPane() we're manipulating
local tree_view = nil



-- Clear out all stuff in Micro's messenger
local function clear_messenger()
	messenger:Reset()
	messenger:Clear()
end

-- open_tree setup's the view
local function open_tree()
	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer("", "navbar"), false)
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
    tree_view.Buf:SetOptionNative("statusformatl", "filemanager")
    tree_view.Buf:SetOptionNative("scrollbar", false)

	-- Fill the scanlist, and then print its contents to tree_view
	-- update_current_dir(os.Getwd())
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


function init()
    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.TryBindKey("F5", "lua:navbar.toggle_tree", false)

    -- Lets the user have the filetree auto-open any time Micro is opened
    -- false by default, as it's a rather noticable user-facing change
    config.RegisterCommonOption("navbar", "openonstart", false)

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
            micro.Log(
                "Warning: navbar.openonstart was enabled, but somehow the tree was already open so the option was ignored."
            )
        end
    end

end
