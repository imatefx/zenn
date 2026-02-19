-- Zenn Window Manager Configuration
-- ~/.config/zenn/init.lua

local zenn = require("zenn")

-- Focus: Alt + h/j/k/l
zenn.bind({"alt"}, "h", function() zenn.focus("left") end)
zenn.bind({"alt"}, "l", function() zenn.focus("right") end)
zenn.bind({"alt"}, "j", function() zenn.focus("down") end)
zenn.bind({"alt"}, "k", function() zenn.focus("up") end)

-- Move: Alt+Shift + h/j/k/l
zenn.bind({"alt", "shift"}, "h", function() zenn.move("left") end)
zenn.bind({"alt", "shift"}, "l", function() zenn.move("right") end)
zenn.bind({"alt", "shift"}, "j", function() zenn.move("down") end)
zenn.bind({"alt", "shift"}, "k", function() zenn.move("up") end)

-- Resize: Alt+Ctrl + h/j/k/l
zenn.bind({"alt", "ctrl"}, "h", function() zenn.resize("left") end)
zenn.bind({"alt", "ctrl"}, "l", function() zenn.resize("right") end)
zenn.bind({"alt", "ctrl"}, "j", function() zenn.resize("down") end)
zenn.bind({"alt", "ctrl"}, "k", function() zenn.resize("up") end)

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
