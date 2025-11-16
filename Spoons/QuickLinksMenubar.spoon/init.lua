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
local USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

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

local function calculateWindowPosition(mouseX, mouseY, windowWidth, windowHeight)
    windowWidth = windowWidth or DEFAULT_WINDOW_WIDTH
    windowHeight = windowHeight or DEFAULT_WINDOW_HEIGHT
    
    local screen = hs.screen.mainScreen()
    if mouseX and mouseY then
        for _, s in ipairs(hs.screen.allScreens()) do
            local frame = s:fullFrame()
            if mouseX >= frame.x and mouseX <= frame.x + frame.w and
               mouseY >= frame.y and mouseY <= frame.y + frame.h then
                screen = s
                break
            end
        end
    end
    
    local screenFrame = screen:fullFrame()
    
    local windowX = screenFrame.x + screenFrame.w - windowWidth - WINDOW_OFFSET_X
    local windowY = screenFrame.y + WINDOW_OFFSET_Y
    
    if mouseX and mouseY then
        local offsetFromMouse = 20
        windowX = math.min(mouseX + offsetFromMouse, screenFrame.x + screenFrame.w - windowWidth - WINDOW_OFFSET_X)
        windowY = math.max(mouseY - offsetFromMouse, screenFrame.y + WINDOW_OFFSET_Y)
        windowY = math.min(windowY, screenFrame.y + screenFrame.h - windowHeight - WINDOW_OFFSET_Y)
    end
    
    return windowX, windowY
end

local function createWebview(url, name, width, height)
    if obj._webviews[url] then
        return obj._webviews[url]
    end
    
    local windowWidth = width or DEFAULT_WINDOW_WIDTH
    local windowHeight = height or DEFAULT_WINDOW_HEIGHT
    
    local mousePos = hs.mouse.absolutePosition()
    local windowX, windowY = calculateWindowPosition(mousePos.x, mousePos.y, windowWidth, windowHeight)
    
    local webview = hs.webview.new({
        x = windowX,
        y = windowY,
        w = windowWidth,
        h = windowHeight,
    }):url(url)
      :windowStyle("titled")
      :windowTitle(name)
      :userAgent(USER_AGENT)
      :allowTextEntry(true)
      :allowGestures(true)
      :allowNewWindows(false)
      :closeOnEscape(true)
      :level(hs.drawing.windowLevels.floating)
    
    webview:navigationCallback(function(navigationType)
        if navigationType == "didFinishNavigation" then
            hs.timer.doAfter(0.5, function()
                local currentURL = webview:url()
                
                if currentURL and string.match(string.lower(currentURL), "^https://mail%.google%.com") then
                    local script = [[
                        (function() {
                            if (!document.getElementById('hammerspoon-gmail-css')) {
                                var style = document.createElement('style');
                                style.id = 'hammerspoon-gmail-css';
                                style.textContent = 'div[role=toolbar], div[role=navigation], div[role=navigation] + div, div[role=navigation] + div ~ div:has(div[role=tabpanel]), header[role=banner] { display: none !important; }';
                                (document.head || document.documentElement).appendChild(style);
                            }
                        })();
                    ]]
                    webview:evaluateJavaScript(script)
                end
            end)
        end
    end)
    
    local clickWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown}, function(event)
        local clickPoint = event:location()
        local webviewFrame = webview:frame()
        
        local isInside = clickPoint.x >= webviewFrame.x and 
                        clickPoint.x <= webviewFrame.x + webviewFrame.w and
                        clickPoint.y >= webviewFrame.y and 
                        clickPoint.y <= webviewFrame.y + webviewFrame.h
        
        if not isInside and webview:isVisible() then
            webview:hide()
        end
        
        return false
    end)
    
    clickWatcher:start()
    obj._clickWatchers[url] = clickWatcher
    
    obj._webviews[url] = webview
    return webview
end

local function toggleWebview(url, name, width, height)
    local webview = createWebview(url, name, width, height)
    
    local currentURL = webview:url()
    local needsNavigation = currentURL ~= url
    
    if webview:isVisible() and not needsNavigation then
        webview:hide()
    else
        if needsNavigation then
            webview:url(url)
        end
        
        local windowWidth = width or DEFAULT_WINDOW_WIDTH
        local windowHeight = height or DEFAULT_WINDOW_HEIGHT
        local mousePos = hs.mouse.absolutePosition()
        local windowX, windowY = calculateWindowPosition(mousePos.x, mousePos.y, windowWidth, windowHeight)
        webview:windowTitle(name)
        webview:size({w = windowWidth, h = windowHeight})
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
                    toggleWebview(item.URL, item.name, item.width, item.height)
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

