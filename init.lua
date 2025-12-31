-- local zoomManager = hs.loadSpoon("ZoomWorkplaceManager")
-- zoomManager:init()

local uptimeMenubar = hs.loadSpoon("UptimeMenubar")
uptimeMenubar:init():start()

local vpnMenubar = hs.loadSpoon("VPNMenubar")
vpnMenubar:init():start()

local quickLinksMenubar = hs.loadSpoon("QuickLinksMenubar")
quickLinksMenubar:init():start()

local calendarMenubar = hs.loadSpoon("CalendarMenubar")
calendarMenubar:init():start()

local dismissMeetingMenubar = hs.loadSpoon("DismissMeetingMenubar")
dismissMeetingMenubar:init():start()

local stageManagerUtilities = hs.loadSpoon("StageManagerUtilities")
stageManagerUtilities:start()
