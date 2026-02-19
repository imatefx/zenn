-- Zenn Window Manager Configuration
-- ~/.config/zenn/init.lua

local zenn = require("zenn")

-- Focus: Alt + Arrow Keys
zenn.bind({"alt"}, "left", function() zenn.focus("left") end)
zenn.bind({"alt"}, "right", function() zenn.focus("right") end)
zenn.bind({"alt"}, "down", function() zenn.focus("down") end)
zenn.bind({"alt"}, "up", function() zenn.focus("up") end)

-- Move: Alt+Shift + Arrow Keys
zenn.bind({"alt", "shift"}, "left", function() zenn.move("left") end)
zenn.bind({"alt", "shift"}, "right", function() zenn.move("right") end)
zenn.bind({"alt", "shift"}, "down", function() zenn.move("down") end)
zenn.bind({"alt", "shift"}, "up", function() zenn.move("up") end)

-- Merge into split: Alt+Ctrl+Shift + Arrow Keys
zenn.bind({"alt", "ctrl", "shift"}, "left", function() zenn.merge("left") end)
zenn.bind({"alt", "ctrl", "shift"}, "right", function() zenn.merge("right") end)
zenn.bind({"alt", "ctrl", "shift"}, "down", function() zenn.merge("down") end)
zenn.bind({"alt", "ctrl", "shift"}, "up", function() zenn.merge("up") end)

-- Eject from split: Alt+E
zenn.bind({"alt"}, "e", function() zenn.eject() end)

-- Resize: Alt+Ctrl + Arrow Keys
zenn.bind({"alt", "ctrl"}, "left", function() zenn.resize("left") end)
zenn.bind({"alt", "ctrl"}, "right", function() zenn.resize("right") end)
zenn.bind({"alt", "ctrl"}, "down", function() zenn.resize("down") end)
zenn.bind({"alt", "ctrl"}, "up", function() zenn.resize("up") end)

-- Workspaces: Alt + 1-9
for i = 1, 9 do
    zenn.bind({"alt"}, tostring(i), function() zenn.workspace(i) end)
    zenn.bind({"alt", "shift"}, tostring(i), function() zenn.move_to_workspace(i) end)
end

-- Toggle modes
zenn.bind({"alt"}, "f", function() zenn.toggle_fullscreen() end)
zenn.bind({"alt", "shift"}, "f", function() zenn.toggle_floating() end)
zenn.bind({"alt", "shift"}, "s", function() zenn.toggle_sticky() end)

-- Split direction
zenn.bind({"alt"}, "v", function() zenn.set_split("vertical") end)
zenn.bind({"alt"}, "b", function() zenn.set_split("horizontal") end)

-- Layout presets
zenn.bind({"alt"}, "=", function() zenn.preset("equal") end)

-- Reload config
zenn.bind({"alt", "shift"}, "r", function() zenn.reload() end)

-- Window rules
zenn.rule({ app = "System Settings", floating = true })
zenn.rule({ app = "Calculator", floating = true })
zenn.rule({ app = "Finder", title = "Copy", floating = true })

-- Gaps
zenn.gaps({ inner = 8, outer = 8 })
