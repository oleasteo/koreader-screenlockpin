local logger = require("logger")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")

local BackgroundWidget = Widget:extend {
    toast = true,
    is_always_active = true,
    invisible = true,

    stopped = false,
}

function BackgroundWidget:init()
    logger.dbg("Initializing background widget:", self.name or self)
    UIManager:show(self)
end

function BackgroundWidget:onClose(cause)
    if self.stopped then return end
    logger.dbg("Closing background widget ( cause =", cause, "):", self.name or self)
    UIManager:close(self)
    self.stopped = true
end

function BackgroundWidget:onExit() self:onClose("exit event") end
function BackgroundWidget:onRestart() self:onClose("restart event") end

return BackgroundWidget
