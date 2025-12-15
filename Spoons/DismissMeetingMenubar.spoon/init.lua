local obj = {
    name = "DismissMeetingMenubar",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _menubar = nil,
}

local MENUBAR_ICON_SIZE = 22
local SHORTCUT_NAME = "Dismiss Nearest Meeting"

local function createCalendarIcon()
    local canvas = hs.canvas.new({
        x = 0,
        y = 0,
        w = MENUBAR_ICON_SIZE,
        h = MENUBAR_ICON_SIZE,
    })
    
    canvas[1] = {
        type = "text",
        text = "🗓️",
        textFont = hs.styledtext.defaultFonts.systemFont,
        textSize = MENUBAR_ICON_SIZE - 2,
        textAlignment = "center",
        frame = {
            x = 0,
            y = 0,
            w = MENUBAR_ICON_SIZE,
            h = MENUBAR_ICON_SIZE,
        },
    }
    
    local xSize = 6
    local padding = 1
    local xX = padding + 2
    local xY = MENUBAR_ICON_SIZE - padding - xSize
    
    canvas[2] = {
        type = "segments",
        action = "stroke",
        strokeColor = { red = 1, green = 0, blue = 0 },
        strokeWidth = 2,
        coordinates = {
            {x = xX, y = xY},
            {x = xX + xSize, y = xY + xSize},
        },
    }
    
    canvas[3] = {
        type = "segments",
        action = "stroke",
        strokeColor = { red = 1, green = 0, blue = 0 },
        strokeWidth = 2,
        coordinates = {
            {x = xX + xSize, y = xY},
            {x = xX, y = xY + xSize},
        },
    }
    
    return canvas:imageFromCanvas()
end

local function runShortcut()
    local task = hs.task.new("/usr/bin/shortcuts", function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 then
            hs.notify.new({
                title = "Dismiss Meeting",
                informativeText = "Failed to run shortcut: " .. (stdErr or "Unknown error"),
            }):send()
        end
    end, {"run", SHORTCUT_NAME})
    task:start()
end

function obj:init()
    if self._menubar then
        return self
    end
    
    self._menubar = hs.menubar.new()
    if not self._menubar then
        error("Failed to create menubar item")
    end
    
    local icon = createCalendarIcon()
    self._menubar:setIcon(icon, false)
    self._menubar:setClickCallback(runShortcut)
    
    return self
end

function obj:start()
    return self
end

function obj:stop()
    if self._menubar then
        self._menubar:delete()
        self._menubar = nil
    end
    return self
end

return obj
