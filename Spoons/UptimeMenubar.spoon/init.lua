local obj = {
    name = "UptimeMenubar",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _menubar = nil,
    _timer = nil,
}

local function getBootTime()
    local handle = io.popen("sysctl -n kern.boottime")
    local result = handle:read("*a")
    handle:close()
    
    if result then
        local timestamp = tonumber(result:match("sec = (%d+)"))
        if timestamp then
            return timestamp
        end
    end
    
    return nil
end

local function getUptime()
    local bootTime = getBootTime()
    if not bootTime then
        return {
            days = 0,
            hours = 0,
            minutes = 0,
            seconds = 0,
            totalSeconds = 0
        }
    end
    
    local currentTime = os.time()
    local totalSeconds = currentTime - bootTime
    
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = math.floor(totalSeconds % 60)
    
    return {
        days = days,
        hours = hours,
        minutes = minutes,
        seconds = seconds,
        totalSeconds = totalSeconds
    }
end

local function getUptimeColor(days)
    if days > 30 then
        return { red = 1, green = 0, blue = 0 }
    elseif days > 25 then
        return { red = 1, green = 1, blue = 0 }
    end
    return nil
end

local function updateMenubar()
    local uptime = getUptime()
    local title = "⬆︎" .. uptime.days
    local color = getUptimeColor(uptime.days)
    
    obj._menubar:setTitle(hs.styledtext.new(title, { color = color }))
end

local function createMenu()
    local uptime = getUptime()
    
    return {
        {
            title = string.format("Uptime: %d days, %d hours, %d minutes", 
                uptime.days, uptime.hours, uptime.minutes),
            disabled = true
        },
        {
            title = string.format("Total: %.0f seconds", uptime.totalSeconds),
            disabled = true
        }
    }
end

function obj:init()
    if self._menubar then
        return self
    end
    
    self._menubar = hs.menubar.new()
    if not self._menubar then
        error("Failed to create menubar item")
    end

    self._menubar:setTitle("⬆︎0")
    self._menubar:setMenu(createMenu)
    
    self._timer = hs.timer.doEvery(60, updateMenubar)
    
    updateMenubar()
    
    return self
end

function obj:start()
    if self._timer then
        self._timer:start()
    end
    return self
end

function obj:stop()
    if self._timer then
        self._timer:stop()
    end
    if self._menubar then
        self._menubar:delete()
    end
    return self
end

return obj
