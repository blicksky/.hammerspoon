local obj = {
    name = "ZoomWorkplaceManager",
    version = "1.0",
    author = "Andrew Blick",
    license = "MIT",
    homepage = "https://github.com/blicksky/hammerspoon-config",
    _lastCheckTime = 0,  -- Track last check time to prevent duplicates
    _windowWatcher = nil, -- Store window watcher
}

-- Constants
local ZOOM_APP_BUNDLE_ID = "zoom.us"
local ZOOM_WORKPLACE_TITLE = "Zoom Workplace"
local ZOOM_MEETING_TITLE = "Zoom Meeting"

-- Ensure window extension is loaded
local window = require("hs.window")
if not window then
    error("Failed to load hs.window extension")
end

local function checkWindows(win, app, event)
    -- Skip if any parameters are nil
    if not win or not app then
        hs.printf("Window watcher callback received nil parameters (win: %s, app: %s, event: %s)", 
            win and "present" or "nil",
            app and "present" or "nil",
            event or "nil"
        )
        return
    end

    -- Skip if app is not Zoom
    local bundleID = app:bundleID()
    if not bundleID or bundleID ~= ZOOM_APP_BUNDLE_ID then
        return
    end

    -- Prevent duplicate checks within 0.5 seconds
    local now = hs.timer.secondsSinceEpoch()
    if now - obj._lastCheckTime < 0.5 then
        return
    end
    obj._lastCheckTime = now

    hs.printf("\nChecking Zoom windows (event: %s)...", event)
    
    -- Get all windows safely
    local allWindows = {}
    local success, result = pcall(function() return app:allWindows() end)
    if success and result then
        allWindows = result
    else
        hs.printf("  Error getting windows: %s", result)
        return
    end

    local hasMeetingWindow = false
    local workplaceWindow = nil

    hs.printf("  All Zoom windows:")
    for _, win in ipairs(allWindows) do
        -- Get window properties safely
        local title, isVisible, isMinimized, frame
        success, result = pcall(function()
            return win:title(), win:isVisible(), win:isMinimized(), win:frame()
        end)
        
        if success then
            title, isVisible, isMinimized, frame = result
        else
            hs.printf("    - Error getting window properties: %s", result)
            goto continue
        end

        hs.printf("    - '%s' (visible: %s, minimized: %s, frame: %s)", 
            title or "unknown", 
            isVisible and "yes" or "no",
            isMinimized and "yes" or "no",
            frame and string.format("%.0f,%.0f %.0fx%.0f", frame.x, frame.y, frame.w, frame.h) or "nil"
        )
        
        if title == ZOOM_MEETING_TITLE then
            hasMeetingWindow = true
            hs.printf("      ^ Found meeting window")
        elseif title == ZOOM_WORKPLACE_TITLE then
            workplaceWindow = win
            hs.printf("      ^ Found workplace window")
        end

        ::continue::
    end

    -- If we have both windows, close the workplace window safely
    if hasMeetingWindow and workplaceWindow then
        hs.printf("  Both windows found, attempting to close workplace window")
        success, result = pcall(function() workplaceWindow:close() end)
        if not success then
            hs.printf("  Error closing workplace window: %s", result)
        end
    else
        hs.printf("  Not closing workplace window:")
        if not hasMeetingWindow then
            hs.printf("    - No meeting window found")
        end
        if not workplaceWindow then
            hs.printf("    - No workplace window found")
        end
    end
end

local function startWindowWatcher()
    -- Clean up any existing watcher
    if obj._windowWatcher then
        obj._windowWatcher:stop()
        obj._windowWatcher = nil
    end

    hs.printf("Starting window watcher...")
    
    -- Ensure window extension is loaded and available
    if not window.watcher then
        hs.printf("Window watcher not available, attempting to reload window extension...")
        window = require("hs.window")
        if not window.watcher then
            hs.printf("Error: Window watcher still not available after reload")
            return
        end
    end

    -- Create watcher with explicit error handling
    local success, watcher = pcall(function()
        local w = window.watcher.new(checkWindows)
        if not w then
            error("Failed to create window watcher")
        end
        return w
    end)
    
    if success and watcher then
        obj._windowWatcher = watcher
        success, result = pcall(function() obj._windowWatcher:start() end)
        if success then
            hs.printf("Window watcher started successfully")
        else
            hs.printf("Error starting window watcher: %s", result)
            obj._windowWatcher = nil
        end
    else
        hs.printf("Error creating window watcher: %s", watcher)
    end
end

local function stopWindowWatcher()
    if obj._windowWatcher then
        hs.printf("Stopping window watcher...")
        obj._windowWatcher:stop()
        obj._windowWatcher = nil
    end
end

function obj:init()
    -- Watch for Zoom app activation
    local appWatcher = hs.application.watcher.new(function(appName, eventType, app)
        if appName ~= ZOOM_APP_BUNDLE_ID then
            return
        end

        local eventNames = {
            [hs.application.watcher.launched] = "launched",
            [hs.application.watcher.terminated] = "terminated",
            [hs.application.watcher.activated] = "activated",
            [hs.application.watcher.deactivated] = "deactivated",
            [hs.application.watcher.hidden] = "hidden",
            [hs.application.watcher.unhidden] = "unhidden"
        }
        
        hs.printf("\nZoom app event: %s (%s)", eventType, eventNames[eventType] or "unknown")
        
        if eventType == hs.application.watcher.activated then
            hs.printf("Zoom activated, will start window watcher in 1.0s...")
            hs.timer.doAfter(1.0, startWindowWatcher)
        elseif eventType == hs.application.watcher.deactivated then
            stopWindowWatcher()
        end
    end)

    -- Start the watcher
    hs.printf("Starting Zoom Workplace Manager...")
    appWatcher:start()
    
    return self
end

return obj 