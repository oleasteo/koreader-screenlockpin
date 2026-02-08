local _ = require("gettext")
local ButtonTable = require("ui/widget/buttontable")

local pluginSettings = require("plugin/settings")

local PinButtonTable = ButtonTable:extend {
    state = nil,
    zero_sep = true,
}

function PinButtonTable:init()
    self.buttons = self.state:makeButtons()
    ButtonTable.init(self)
    self:post_init()
end

local function _button_onTapSelectNoFeedback(button)
    if button.enabled or button.allow_tap_when_disabled then
        button.callback()
    end
    if button.readonly ~= true then
        return true
    end
end

function PinButtonTable:post_init()
    if pluginSettings.getButtonFeedback() == "off" then
        for _, line in ipairs(self.buttons_layout) do
            for _, button in ipairs(line) do
                button.onTapSelectButton = _button_onTapSelectNoFeedback
            end
        end
    end
end

function PinButtonTable:rescale(next_width)
    self:free()
    self.dimen = nil
    self.width = next_width
    ButtonTable.init(self)
    self:post_init()
end

return PinButtonTable
