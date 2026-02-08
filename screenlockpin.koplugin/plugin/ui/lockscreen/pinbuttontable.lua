local _ = require("gettext")
local Size = require("ui/size")
local ButtonTable = require("ui/widget/buttontable")

local pluginSettings = require("plugin/settings")

local PinButtonTable = ButtonTable:extend {
    state = nil,
    font_size = nil,
    size_factor = 1.25,
    zero_sep = true,
}

function PinButtonTable:init()
    self.buttons = self:makeButtonTemplates()
    ButtonTable.init(self)
    self:adaptButtons()
end

function PinButtonTable:makeButtonTemplates()
    local action_button_height = Size.item.height_large + Size.padding.buttontable
    local button_height = action_button_height * self.size_factor

    local delete_button = {
        text = "⌫",
        height = button_height,
        font_size = self.font_size,
        callback = function() self.state:delInput(false) end,
        hold_callback = function() self.state:delInput(true) end,
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
            enabled = self.state.valid,
            callback = function() self.state.on_submit(self.state.value) end,
        })
    end

    local function digitButton(num)
        return {
            text = num,
            height = button_height,
            font_size = self.font_size,
            callback = function() self.state:appendInput(num) end
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

local function _button_onTapSelectNoFeedback(button)
    if button.enabled or button.allow_tap_when_disabled then
        button.callback()
    end
    if button.readonly ~= true then
        return true
    end
end

function PinButtonTable:adaptButtons()
    if pluginSettings.getButtonFeedback() == "off" then
        for _, line in ipairs(self.buttons_layout) do
            for _, button in ipairs(line) do
                button.onTapSelectButton = _button_onTapSelectNoFeedback
            end
        end
    end
end

function PinButtonTable:rescale(scaling)
    self:free()
    self.dimen = nil
    self.font_size = scaling.font_size
    self.width = scaling.width
    self:init()
end

return PinButtonTable
