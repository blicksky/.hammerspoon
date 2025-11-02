local obj = {
    name = "VPNMenubar",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _menubar = nil,
    _configWatcher = nil,
    _lastChanged = nil,
    _isConnected = false,
    _config = nil,
}

local carrotOrange = {red = 0.996, green = 0.553, blue = 0.314}

local configLoader = require("lib.config_loader")

local function loadConfig()
    local defaults = {
        interface = "utun4",
        ipPattern = "10%.%d+%.%d+%.%d+"
    }
    
    local configPath = hs.spoons.resourcePath("config.lua")
    return configLoader.load(defaults, configPath)
end

local function findVPNInterface()
    local interface = obj._config.interface
    local ipPattern = obj._config.ipPattern
    
    local output = hs.execute("ifconfig " .. interface .. " 2>&1")
    
    if output:match("does not exist") then
        return false
    end
    
    local ipAddress = output:match("inet%s+(" .. ipPattern .. ")")
    if ipAddress then
        return true
    end
    
    return false
end

local function checkVPNStatus()
    return findVPNInterface()
end

local function formatLastChanged()
    if not obj._lastChanged then
        return "Never"
    end
    
    return os.date("%H:%M:%S", obj._lastChanged)
end

local function generateVPNIcon(isConnected)
    local icon_size = {w = 18, h = 18}
    
    local canvas = hs.canvas.new(icon_size)
    
    local iconPath = isConnected and "icons/locked.png" or "icons/unlocked.png"
    local fullIconPath = hs.spoons.resourcePath(iconPath)
    local lockIcon = hs.image.imageFromPath(fullIconPath)
    
    canvas[1] = {
        type = "image",
        image = lockIcon,
        frame = {x = 0, y = 0, w = icon_size.w, h = icon_size.h},
        imageScaling = "scaleProportionally",
        imageAlignment = "center"
    }
    
    local image_object = canvas:imageFromCanvas()
    canvas:delete()
    
    return image_object
end

local function updateMenubar()
    local icon = generateVPNIcon(obj._isConnected)
    obj._menubar:setIcon(icon, false)
    
    if obj._isConnected then
        local styledTitle = hs.styledtext.new("VPN", {
            color = carrotOrange
        })
        obj._menubar:setTitle(styledTitle)
    else
        obj._menubar:setTitle("VPN")
    end
end

local function updateVPNStatus()
    local wasConnected = obj._isConnected
    obj._isConnected = checkVPNStatus()
    
    if wasConnected ~= obj._isConnected then
        obj._lastChanged = os.time()
        updateMenubar()
    end
end

local function networkConfigCallback()
    updateVPNStatus()
end

local function createMenu()
    local statusText = obj._isConnected and "Connected" or "Disconnected"
    
    return {
        {
            title = "VPN Status: " .. statusText,
            disabled = true
        },
        {
            title = "Last changed: " .. formatLastChanged(),
            disabled = true
        }
    }
end

function obj:init()
    if self._menubar then
        return self
    end
    
    self._config = loadConfig()
    
    self._menubar = hs.menubar.new()
    if not self._menubar then
        error("Failed to create menubar item")
    end

    local initialIcon = generateVPNIcon(false)
    self._menubar:setIcon(initialIcon, false)
    self._menubar:setTitle("VPN")
    self._menubar:setMenu(createMenu)
    
    self._configWatcher = hs.network.configuration.open()
    self._configWatcher:monitorKeys({"State:/Network/Interface/.*"}, true)
    self._configWatcher:setCallback(networkConfigCallback)
    self._configWatcher:start()
    
    updateVPNStatus()
    
    return self
end

function obj:start()
    if self._configWatcher then
        self._configWatcher:start()
    end
    return self
end

function obj:stop()
    if self._configWatcher then
        self._configWatcher:stop()
    end
    if self._menubar then
        self._menubar:delete()
    end
    return self
end

return obj
