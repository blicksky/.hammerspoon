local STAGE_MANAGER_APP = "WindowManager"
local STAGE_MANAGER_ROLE = "AXButton"

local obj = {}
obj.__index = obj

obj.name = "StageManagerUtilities"
obj.version = "1.0"
obj.author = "Andrew Blick"
obj.license = "MIT"

obj.eventTap = nil
obj.windowFilter = nil
obj.lastStageManagerCmdClickTime = nil
obj.stageManagerWindowThreshold = 0.3

function obj:start()
    if self.eventTap then
        self.eventTap:stop()
    end
    if self.windowFilter then
        self.windowFilter:unsubscribeAll()
    end

    self.eventTap = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
    }, function(event)
        self:handleClick(event)
        return false
    end)

    self.windowFilter = hs.window.filter.new():setDefaultFilter()
    self.windowFilter:subscribe(hs.window.filter.windowFocused, function(window)
        self:handleWindowFocus(window)
    end)

    self.eventTap:start()
    return self
end

function obj:stop()
    if self.eventTap then
        self.eventTap:stop()
        self.eventTap = nil
    end
    if self.windowFilter then
        self.windowFilter:unsubscribeAll()
        self.windowFilter = nil
    end
    return self
end

function obj:handleClick(event)
    local flags = event:getFlags()
    if not flags.cmd then
        return
    end

    if self:isStageManagerClick(event:location()) then
        self.lastStageManagerCmdClickTime = hs.timer.secondsSinceEpoch()
    end
end

function obj:handleWindowFocus(window)
    if not self.lastStageManagerCmdClickTime then
        return
    end

    local elapsed = hs.timer.secondsSinceEpoch() - self.lastStageManagerCmdClickTime
    self.lastStageManagerCmdClickTime = nil

    if elapsed <= self.stageManagerWindowThreshold and window then
        window:close()
    end
end

function obj:isStageManagerClick(point)
    local element = hs.axuielement.systemElementAtPosition(point)
    if not element then
        return false
    end

    local pid = element:pid()
    if not pid then
        return false
    end

    local app = hs.application.applicationForPID(pid)
    if not app then
        return false
    end

    return app:name() == STAGE_MANAGER_APP and element:attributeValue("AXRole") == STAGE_MANAGER_ROLE
end

return obj
