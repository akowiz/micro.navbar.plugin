VERSION = "0.0.1"

local micro = import("micro")
local config = import("micro/config")
local util = import("micro/util")

function init()
    config.MakeCommand("navbar", navbarToggle, config.NoComplete)
    config.AddRuntimeFile("navbar", config.RTHelp, "help/navbar.md")
    config.TryBindKey("F5", "lua:navbar.navbarToggle", false)
end

function navbarToggle(bp)
	micro.InfoBar():Message("navbar toggle")
end
