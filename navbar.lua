VERSION = "0.0.1"

local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")

function init()
    config.MakeCommand("navbar", navbarToggle, config.NoComplete)
    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.TryBindKey("F5", "lua:navbar.navbarToggle", false)
    visible = false
end

function navbarToggle(bp)
    visible = not visible
	micro.InfoBar():Message("navbar toggle "..tostring(visible))
end
