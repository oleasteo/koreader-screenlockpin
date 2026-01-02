local _ = require("gettext")
local Device = require("device")
local InputContainer = require("ui/widget/container/inputcontainer")
local GestureRange = require("ui/gesturerange")
local Screen = Device.screen

local mathu = require("plugin/util/math")

local OutsideAreaInput = InputContainer:extend {
    name = "SLPOutsideArea",
    content_region = nil,
}

function OutsideAreaInput:init()
    if Device:isTouchDevice() then
        -- use a function to adapt to screen resize
        local range = function () return Screen:getSize() end
        self.ges_events.TapScreen = { GestureRange:new{ ges = "tap", range = range } }
        self.ges_events.HoldScreen = { GestureRange:new{ ges = "hold", range = range } }
    end
    self.screen_mid = Screen:getHeight() / 2
    if Device:hasFrontlight() then
        self.brightness_step = math.floor(Device.powerd.fl_max / 5 + 0.5)
    end
end

function OutsideAreaInput:nextBrightness(direction)
    if not self.brightness_step then return end
    local brightness = Device.powerd:frontlightIntensity()
    local step = direction >= 0 and self.brightness_step or -self.brightness_step
    Device.powerd:setIntensity(mathu.clamp(brightness + step, Device.powerd.fl_min, Device.powerd.fl_max))
end

function OutsideAreaInput:maxBrightness(direction)
    Device.powerd:setIntensity(direction >= 0 and Device.powerd.fl_max or Device.powerd.fl_min)
end

function OutsideAreaInput:onTapScreen(_, ges)
    if not ges or not ges.pos or not self.content_region then return false end
    if not mathu.isOutside(ges.pos, self.content_region) then return false end
    self:nextBrightness(self.screen_mid - ges.pos.y)
    -- consume event
    return true
end

function OutsideAreaInput:onHoldScreen(_, ges)
    if not ges or not ges.pos or not self.content_region then return false end
    if not mathu.isOutside(ges.pos, self.content_region) then return false end
    self:maxBrightness(self.screen_mid - ges.pos.y)
    -- consume event
    return true
end

return OutsideAreaInput
