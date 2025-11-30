local obj = {
    name = "CalendarMenubar",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _menubar = nil,
    _webview = nil,
    _canvas = nil,
    _timer = nil,
    _webviewVisible = false,
    _webviewOrigin = nil,
}

local DEFAULT_WINDOW_WIDTH = 600
local DEFAULT_WINDOW_HEIGHT = 500
local WINDOW_OFFSET_X = 10
local WINDOW_OFFSET_Y = 25
local MOUSE_OFFSET = 20
local GOOGLE_CALENDAR_URL = table.concat({
    "https://calendar.google.com/calendar/embed",
    "?src=primary",
    "&src=en.usa%23holiday@group.v.calendar.google.com",
}, "")

local USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

local MENUBAR_ICON_SIZE = 22
local MONTH_ABBREVIATIONS = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

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

local function clampWindowOrigin(origin, windowWidth, windowHeight)
    local screen = findScreenContainingPoint(origin.x, origin.y)
    local screenFrame = screen:fullFrame()

    local clampedX = math.max(
        screenFrame.x + WINDOW_OFFSET_X,
        math.min(origin.x, screenFrame.x + screenFrame.w - windowWidth - WINDOW_OFFSET_X)
    )

    local clampedY = math.max(
        screenFrame.y + WINDOW_OFFSET_Y,
        math.min(origin.y, screenFrame.y + screenFrame.h - windowHeight - WINDOW_OFFSET_Y)
    )

    return {
        x = clampedX,
        y = clampedY,
    }
end

local function getMenubarAnchoredOrigin(windowWidth, windowHeight)
    if not obj._menubar then
        return nil
    end

    local success, menuFrame = pcall(function()
        return obj._menubar:frame()
    end)

    if not success or not menuFrame then
        return nil
    end

    local origin = {
        x = menuFrame.x + (menuFrame.w / 2) - (windowWidth / 2),
        y = menuFrame.y + menuFrame.h + WINDOW_OFFSET_Y,
    }

    return clampWindowOrigin(origin, windowWidth, windowHeight)
end

local function getMouseAnchoredOrigin(windowWidth, windowHeight)
    local mousePos = hs.mouse.absolutePosition()

    local origin = {
        x = mousePos.x + MOUSE_OFFSET - (windowWidth / 2),
        y = mousePos.y - MOUSE_OFFSET,
    }

    return clampWindowOrigin(origin, windowWidth, windowHeight)
end

local function refreshWebviewOrigin()
    local anchoredOrigin = getMenubarAnchoredOrigin(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)
    if anchoredOrigin then
        obj._webviewOrigin = anchoredOrigin
        return obj._webviewOrigin
    end

    obj._webviewOrigin = getMouseAnchoredOrigin(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)
    return obj._webviewOrigin
end

local function hideWebviewIfVisible(targetWebview)
    if not obj._webviewVisible or not targetWebview then
        return
    end

    local success = pcall(function()
        targetWebview:hide()
    end)

    if success then
        obj._webviewVisible = false
    end
end

local function handleWebviewWindowEvent(action, webview, state)
    if action ~= "focusChange" then
        return
    end

    if state then
        obj._webviewVisible = true
        return
    end

    hideWebviewIfVisible(webview)
end

local function focusWebviewSoon(webview)
    hs.timer.doAfter(0, function()
        local hswindow = webview:hswindow()
        if hswindow then
            hswindow:focus()
        end
    end)
end

local function createWebview()
    if obj._webview then
        return obj._webview
    end
    
    local origin = refreshWebviewOrigin()
    
    local webview = hs.webview.new({
        x = origin.x,
        y = origin.y,
        w = DEFAULT_WINDOW_WIDTH,
        h = DEFAULT_WINDOW_HEIGHT,
    }):url(GOOGLE_CALENDAR_URL)
      :windowStyle("titled")
      :windowTitle("Google Calendar")
      :userAgent(USER_AGENT)
      :allowTextEntry(true)
      :allowGestures(true)
      :allowNewWindows(false)
      :closeOnEscape(true)
      :level(hs.drawing.windowLevels.floating)
      :windowCallback(handleWebviewWindowEvent)
    
    obj._webview = webview
    
    return webview
end

local function showWebview()
    if not obj._webview then
        createWebview()
    end
    
    local webview = obj._webview
    local origin = refreshWebviewOrigin()
    
    webview:topLeft(origin)
    webview:level(hs.drawing.windowLevels.floating)
    webview:show()
    webview:bringToFront()
    focusWebviewSoon(webview)
    obj._webviewVisible = true
end

local function toggleWebview()
    if obj._webviewVisible then
        hideWebviewIfVisible(obj._webview)
    else
        showWebview()
    end
end

local function createDateIcon()
    local date = os.date("*t")
    local day = date.day
    local monthAbbr = MONTH_ABBREVIATIONS[date.month]
    
    local canvas = hs.canvas.new({
        x = 0,
        y = 0,
        w = MENUBAR_ICON_SIZE,
        h = MENUBAR_ICON_SIZE,
    })
    
    local monthHeight = MENUBAR_ICON_SIZE * 0.33
    local dateHeight = MENUBAR_ICON_SIZE * 0.67
    
    canvas[1] = {
        type = "text",
        text = monthAbbr,
        textFont = hs.styledtext.defaultFonts.systemFont,
        textSize = 7,
        textColor = { white = 1 },
        textAlignment = "center",
        frame = {
            x = 0,
            y = 0,
            w = MENUBAR_ICON_SIZE,
            h = monthHeight,
        },
    }
    
    canvas[2] = {
        type = "text",
        text = tostring(day),
        textFont = hs.styledtext.defaultFonts.systemFont,
        textSize = 12,
        textColor = { white = 1 },
        textAlignment = "center",
        frame = {
            x = 0,
            y = monthHeight,
            w = MENUBAR_ICON_SIZE,
            h = dateHeight,
        },
    }
    
    return canvas:imageFromCanvas()
end

local function updateMenubar()
    local icon = createDateIcon()
    if icon and obj._menubar then
        obj._menubar:setIcon(icon, false)
    end
end


function obj:init()
    if self._menubar then
        return self
    end
    
    self._menubar = hs.menubar.new()
    if not self._menubar then
        error("Failed to create menubar item")
    end
    
    updateMenubar()
    self._menubar:setClickCallback(toggleWebview)
    
    self._timer = hs.timer.doAt("00:00", "1d", updateMenubar)
    
    return self
end

function obj:start()
    updateMenubar()
    if self._timer then
        self._timer:start()
    end
    return self
end

function obj:stop()
    if self._timer then
        self._timer:stop()
        self._timer = nil
    end
    
    if self._canvas then
        self._canvas:delete()
        self._canvas = nil
    end
    
    if self._webview then
        self._webview:delete()
        self._webview = nil
    end
    
    if self._menubar then
        self._menubar:delete()
        self._menubar = nil
    end
    
    self._webviewOrigin = nil
    
    return self
end

return obj

