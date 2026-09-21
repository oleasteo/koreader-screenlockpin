local _ = require("gettext")
local logger = require("logger")
local EventListener = require("ui/widget/eventlistener")

local pluginSettings = require("plugin/settings")
local Throttle = require("plugin/state/throttle")

local LENGTH_RANGE = {3, 12}

local PinInputState = EventListener:extend {
    -- configuration
    placeholder = "",
    obfuscate = true,

    -- events
    on_display_update = nil, -- (display_text, {placeholder?:bool,throttle?:bool})
    on_update = nil, -- (value)
    on_submit = nil, -- (value)
    on_valid_state = nil, -- (valid)

    -- internal state
    value = "",
    display = "",
    valid = false,
    rate_limit = nil
}

function PinInputState:init()
    if pluginSettings.shouldRateLimit() then
        self.throttle = Throttle:new {
            on_resume = function() self:reevaluate() end
        }
    end
    self:reevaluate()
end

--- Whether the rate limit blocks input; refreshes the countdown on the way out.
function PinInputState:_isThrottled()
    if not (self.throttle and self.throttle:isPaused()) then return false end
    self:reevaluate()
    return true
end

function PinInputState:appendInput(val)
    if self:_isThrottled() then return end
    if #self.value < LENGTH_RANGE[2] then
        self.value = self.value .. val
        self:reevaluate()
    end
end

function PinInputState:delInput(everything)
    if self:_isThrottled() then return end
    if everything then
        self:clear()
    else
        self.value = self.value:sub(1, -2)
        self:reevaluate()
    end
end

function PinInputState:setDisplayText(next_display, options)
    if not (self.display == next_display) then
        self.display = next_display
        if self.on_display_update then self.on_display_update(next_display, options) end
    end
end

function PinInputState:incFailedCount()
    if not self.throttle then return end
    self.throttle:pushAt(#self.value)
    if self.throttle:isPaused() then self:clear() end
end

function PinInputState:reevaluate()
    if self.throttle and self.throttle:isPaused() then
        local next_display = _("Try again in " .. self.throttle:remainingSeconds() .. "s")
        logger.dbg("ScreenLockPin: pininput reevaluate " .. next_display)
        self:setDisplayText(next_display, { throttle = true })
        return
    end

    -- refresh display
    local show_placeholder = #self.value == 0
    local next_display
    if show_placeholder then
        next_display = self.placeholder
    elseif self.obfuscate then
        next_display = string.rep("●", #self.value)
    else
        next_display = self.value
    end
    --logger.dbg("ScreenLockPin: pininput reevaluate " .. next_display)
    logger.dbg("ScreenLockPin: pininput reevaluate [redacted]")
    self:setDisplayText(next_display, { placeholder = show_placeholder })
    -- refresh valid state and check
    local next_valid = #self.value >= LENGTH_RANGE[1] and #self.value <= LENGTH_RANGE[2]
    if next_valid and self.on_update then self.on_update(self.value) end
    if self.valid ~= next_valid then
        self.valid = next_valid
        if self.on_valid_state then self.on_valid_state(next_valid) end
    end
end

function PinInputState:clear()
    self.value = ""
    self:reevaluate()
end

return PinInputState
