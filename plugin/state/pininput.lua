local _ = require("gettext")
local logger = require("logger")
local Size = require("ui/size")
local EventListener = require("ui/widget/eventlistener")

local pluginSettings = require("plugin/settings")
local Throttle = require("plugin/state/throttle")

local LENGTH_RANGE = {3, 12}

local PinInputState = EventListener:extend {
    -- configuration
    placeholder = "",
    size_factor = 1.25,
    font_size = nil,

    -- events
    on_display_update = nil, -- (display_text)
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

function PinInputState:makeButtons()
    local action_button_height = Size.item.height_large + Size.padding.buttontable
    local button_height = action_button_height * self.size_factor

    local delete_button = {
        text = "⌫",
        height = button_height,
        font_size = self.font_size,
        callback = function()
            if self.throttle and self.throttle:isPaused() then return end
            self.value = self.value:sub(1, -2)
            self:reevaluate()
        end,
        hold_callback = function()
            if self.throttle and self.throttle:isPaused() then return end
            self:clear()
        end,
    }

    local noop_button = {
        text = " ",
        height = button_height,
        font_size = self.font_size,
        callback = function() end,
        enabled = false,
    }

    local action_row = {}

    if self.on_submit then
        table.insert(action_row, {
            id = "submit",
            text = _("Save"),
            height = action_button_height,
            font_size = self.font_size,
            enabled = self.valid,
            callback = function() self.on_submit(self.value) end,
        })
    end

    local function digitButton(num)
        return {
            text = num,
            height = button_height,
            font_size = self.font_size,
            callback = function()
                if self.throttle and self.throttle:isPaused() then return end
                if #self.value < LENGTH_RANGE[2] then
                    self.value = self.value .. num
                    self:reevaluate()
                end
            end
        }
    end

    local buttons = {
        { digitButton("1"), digitButton("2"), digitButton("3") },
        { digitButton("4"), digitButton("5"), digitButton("6") },
        { digitButton("7"), digitButton("8"), digitButton("9") },
        { noop_button,      digitButton("0"), delete_button },
        action_row
    }

    return buttons
end

function PinInputState:setDisplayText(next_display)
    if not (self.display == next_display) then
        self.display = next_display
        if self.on_display_update then self.on_display_update(next_display) end
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
        self:setDisplayText(next_display)
        return
    end

    -- refresh display
    local next_display = #self.value > 0 and string.rep("●", #self.value) or self.placeholder
    --logger.dbg("ScreenLockPin: pininput reevaluate " .. next_display)
    logger.dbg("ScreenLockPin: pininput reevaluate [redacted]")
    self:setDisplayText(next_display)
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
