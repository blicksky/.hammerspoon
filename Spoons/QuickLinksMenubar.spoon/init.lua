local obj = {
    name = "QuickLinksMenubar",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _menubar = nil,
    _webviews = {},
    _clickWatchers = {},
    _config = nil,
}

local DEFAULT_WINDOW_WIDTH = 400
local DEFAULT_WINDOW_HEIGHT = 500
local WINDOW_OFFSET_X = 10
local WINDOW_OFFSET_Y = 25

local function loadConfig()
    local configPath = hs.spoons.resourcePath("config.json")
    local configFile = io.open(configPath, "r")
    
    if not configFile then
        return {}
    end
    
    local content = configFile:read("*a")
    configFile:close()
    
    if not content or content == "" then
        return {}
    end
    
    local success, data = pcall(function()
        return hs.json.decode(content)
    end)
    
    if not success or not data or type(data) ~= "table" then
        hs.alert.show("Failed to parse config.json")
        return {}
    end
    
    if data.links and type(data.links) == "table" then
        return data.links
    end
    
    return {}
end

local function getMousePosition()
    local mousePoint = hs.mouse.absolutePosition()
    return mousePoint
end

local function calculateWindowPosition(mouseX, mouseY)
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:fullFrame()
    
    local windowX = screenFrame.w - DEFAULT_WINDOW_WIDTH - WINDOW_OFFSET_X
    local windowY = WINDOW_OFFSET_Y
    
    if mouseX and mouseY then
        local offsetFromMouse = 20
        windowX = math.min(mouseX + offsetFromMouse, screenFrame.w - DEFAULT_WINDOW_WIDTH - WINDOW_OFFSET_X)
        windowY = math.max(mouseY - offsetFromMouse, WINDOW_OFFSET_Y)
        windowY = math.min(windowY, screenFrame.h - DEFAULT_WINDOW_HEIGHT - WINDOW_OFFSET_Y)
    end
    
    return windowX, windowY
end

local function createWebview(url, name)
    if obj._webviews[url] then
        return obj._webviews[url]
    end
    
    local mousePos = getMousePosition()
    local windowX, windowY = calculateWindowPosition(mousePos.x, mousePos.y)
    
    local datastore = hs.webview.datastore.newPrivate()
    local preferences = {
        datastore = datastore
    }
    
    local webview = hs.webview.new({
        x = windowX,
        y = windowY,
        w = DEFAULT_WINDOW_WIDTH,
        h = DEFAULT_WINDOW_HEIGHT,
    }, preferences):url(url)
      :windowStyle("titled")
      :windowTitle(name)
      :allowTextEntry(true)
      :allowGestures(true)
      :allowNewWindows(false)
      :closeOnEscape(true)
      :level(hs.drawing.windowLevels.floating)
    
    local clickWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown}, function(event)
        local clickPoint = event:location()
        local webviewFrame = webview:frame()
        
        local isInside = clickPoint.x >= webviewFrame.x and 
                        clickPoint.x <= webviewFrame.x + webviewFrame.w and
                        clickPoint.y >= webviewFrame.y and 
                        clickPoint.y <= webviewFrame.y + webviewFrame.h
        
        if not isInside and webview:isVisible() then
            webview:hide()
            return false
        end
        
        return false
    end)
    
    clickWatcher:start()
    obj._clickWatchers[url] = clickWatcher
    
    obj._webviews[url] = webview
    return webview
end

local function toggleWebview(url, name)
    local webview = createWebview(url, name)
    
    local currentURL = webview:url()
    local needsNavigation = currentURL ~= url
    
    if webview:isVisible() and not needsNavigation then
        webview:hide()
    else
        if needsNavigation then
            webview:url(url)
        end
        local mousePos = getMousePosition()
        local windowX, windowY = calculateWindowPosition(mousePos.x, mousePos.y)
        webview:windowTitle(name)
        webview:topLeft({x = windowX, y = windowY})
        webview:level(hs.drawing.windowLevels.floating)
        webview:show()
        webview:bringToFront()
    end
end

local function createMenu()
    if not obj._config or #obj._config == 0 then
        return {
            {
                title = "No links configured",
                disabled = true
            },
            {
                title = "---"
            },
            {
                title = "Create config.json in spoon directory",
                disabled = true
            }
        }
    end
    
    local menu = {}
    
    for i, item in ipairs(obj._config) do
        if item.name and item.URL then
            table.insert(menu, {
                title = item.name,
                fn = function()
                    toggleWebview(item.URL, item.name)
                end
            })
        end
    end
    
    return menu
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
    
    self._menubar:setTitle("📱")
    self._menubar:setMenu(createMenu)
    
    return self
end

function obj:start()
    return self
end

function obj:stop()
    for url, webview in pairs(self._webviews) do
        if webview then
            webview:delete()
        end
    end
    
    for url, watcher in pairs(self._clickWatchers) do
        if watcher then
            watcher:stop()
        end
    end
    
    self._webviews = {}
    self._clickWatchers = {}
    
    if self._menubar then
        self._menubar:delete()
    end
    
    return self
end

return obj

