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
local MOUSE_OFFSET = 20
local CSS_INJECT_DELAY = 0.5
local ICON_SIZE = 18

local USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

local function loadFile(fileName)
    local filePath = hs.spoons.resourcePath(fileName)
    local file = io.open(filePath, "r")
    
    if not file then
        return nil
    end
    
    local content = file:read("*a")
    file:close()
    
    return content
end

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
    
    local links = {}
    if data.links and type(data.links) == "table" then
        links = data.links
    end
    
    for _, link in ipairs(links) do
        if link.cssFile then
            link.css = loadFile(link.cssFile)
        end
        if link.jsFile then
            link.js = loadFile(link.jsFile)
        end
    end
    
    return links
end

local function findScreenContainingPoint(x, y)
    for _, screen in ipairs(hs.screen.allScreens()) do
        local frame = screen:fullFrame()
        if x >= frame.x and x <= frame.x + frame.w and
           y >= frame.y and y <= frame.y + frame.h then
            return screen
        end
    end
    return hs.screen.mainScreen()
end

local function calculateWindowPosition(mouseX, mouseY, windowWidth, windowHeight)
    windowWidth = windowWidth or DEFAULT_WINDOW_WIDTH
    windowHeight = windowHeight or DEFAULT_WINDOW_HEIGHT
    
    local screen = mouseX and mouseY and findScreenContainingPoint(mouseX, mouseY) or hs.screen.mainScreen()
    local screenFrame = screen:fullFrame()
    
    local windowX = screenFrame.x + screenFrame.w - windowWidth - WINDOW_OFFSET_X
    local windowY = screenFrame.y + WINDOW_OFFSET_Y
    
    if mouseX and mouseY then
        windowX = math.min(mouseX + MOUSE_OFFSET, screenFrame.x + screenFrame.w - windowWidth - WINDOW_OFFSET_X)
        windowY = math.max(mouseY - MOUSE_OFFSET, screenFrame.y + WINDOW_OFFSET_Y)
        windowY = math.min(windowY, screenFrame.y + screenFrame.h - windowHeight - WINDOW_OFFSET_Y)
    end
    
    return windowX, windowY
end

local function getWindowSize(width, height)
    return width or DEFAULT_WINDOW_WIDTH, height or DEFAULT_WINDOW_HEIGHT
end

local function injectCSS(webview, css)
    if not css then
        return
    end
    local escapedCSS = css:gsub("'", "\\'"):gsub("\n", " ")
    local script = string.format([[
        (function() {
            if (!document.getElementById('hammerspoon-custom-css')) {
                var style = document.createElement('style');
                style.id = 'hammerspoon-custom-css';
                style.textContent = '%s';
                (document.head || document.documentElement).appendChild(style);
            }
        })();
    ]], escapedCSS)
    webview:evaluateJavaScript(script)
end

local function injectJS(webview, js)
    if not js then
        return
    end
    local script = string.format([[
        (function() {
            if (window._hammerspoonJsInjected) return;
            window._hammerspoonJsInjected = true;
            %s
        })();
    ]], js)
    webview:evaluateJavaScript(script)
end

local function isPointInsideFrame(point, frame)
    return point.x >= frame.x and point.x <= frame.x + frame.w and
           point.y >= frame.y and point.y <= frame.y + frame.h
end

local function resizeImage(image, size)
    if not image then
        return nil
    end
    local originalSize = image:size()
    if originalSize.w == size and originalSize.h == size then
        return image
    end
    
    local canvas = hs.canvas.new({w = size, h = size})
    canvas[1] = {
        type = "image",
        image = image,
        frame = {x = 0, y = 0, w = size, h = size},
        imageScaling = "scaleProportionally",
        imageAlignment = "center"
    }
    local resized = canvas:imageFromCanvas()
    canvas:delete()
    return resized
end

local function getIconCachePath(itemUrl)
    local tempDir = hs.fs.temporaryDirectory()
    local cacheDir = tempDir .. "QuickLinksMenubar/"
    if not hs.fs.attributes(cacheDir) then
        hs.fs.mkdir(cacheDir)
    end
    local filename = itemUrl:gsub("[^%w%.%-]", "_"):gsub("https?://", ""):gsub("/", "_")
    return cacheDir .. filename .. ".ico"
end

local function getIconImage(itemUrl)
    local cachePath = getIconCachePath(itemUrl)
    if not hs.fs.attributes(cachePath) then
        return nil
    end
    
    local image = hs.image.imageFromPath(cachePath)
    if not image then
        return nil
    end
    
    return resizeImage(image, ICON_SIZE)
end

local function fetchIcon(iconUrl, itemUrl)
    if not iconUrl then
        return
    end
    
    local cachePath = getIconCachePath(itemUrl)
    
    hs.http.asyncGet(iconUrl, {
        ["User-Agent"] = USER_AGENT
    }, function(status, body, headers)
        if status == 200 and body and #body > 0 then
            local file = io.open(cachePath, "wb")
            if file then
                file:write(body)
                file:close()
            end
        end
    end)
end

local function fetchAllIcons()
    if not obj._config then
        return
    end
    
    for _, item in ipairs(obj._config) do
        if item.URL and item.iconUrl then
            fetchIcon(item.iconUrl, item.URL)
        end
    end
end

local function createWebview(url, name, width, height, css, js)
    if obj._webviews[url] then
        return obj._webviews[url]
    end
    
    local windowWidth, windowHeight = getWindowSize(width, height)
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
    
    if css or js then
        webview:navigationCallback(function(navigationType)
            if navigationType == "didFinishNavigation" then
                hs.timer.doAfter(CSS_INJECT_DELAY, function()
                    injectCSS(webview, css)
                    injectJS(webview, js)
                end)
            end
        end)
    end
    
    local clickWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown}, function(event)
        local clickPoint = event:location()
        local webviewFrame = webview:frame()
        
        if not isPointInsideFrame(clickPoint, webviewFrame) and webview:isVisible() then
            webview:hide()
        end
        
        return false
    end)
    
    clickWatcher:start()
    obj._clickWatchers[url] = clickWatcher
    
    obj._webviews[url] = webview
    return webview
end

local function showWebview(webview, name, width, height)
    local windowWidth, windowHeight = getWindowSize(width, height)
    local mousePos = hs.mouse.absolutePosition()
    local windowX, windowY = calculateWindowPosition(mousePos.x, mousePos.y, windowWidth, windowHeight)
    
    webview:windowTitle(name)
    webview:size({w = windowWidth, h = windowHeight})
    webview:topLeft({x = windowX, y = windowY})
    webview:level(hs.drawing.windowLevels.floating)
    webview:show()
    webview:bringToFront()
end

local function toggleWebview(url, name, width, height, css, js)
    local webview = createWebview(url, name, width, height, css, js)
    local currentURL = webview:url()
    local needsNavigation = currentURL ~= url
    
    if webview:isVisible() and not needsNavigation then
        webview:hide()
    else
        if needsNavigation then
            webview:url(url)
        end
        showWebview(webview, name, width, height)
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
    
    for _, item in ipairs(obj._config) do
        if item.name and item.URL then
            local url = item.URL
            local name = item.name
            local width = item.width
            local height = item.height
            local css = item.css
            local js = item.js
            
            local menuItem = {
                title = name,
                fn = function()
                    toggleWebview(url, name, width, height, css, js)
                end
            }
            
            local iconImage = getIconImage(url)
            if iconImage then
                menuItem.image = iconImage
            end
            
            table.insert(menu, menuItem)
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
    
    fetchAllIcons()
    
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

