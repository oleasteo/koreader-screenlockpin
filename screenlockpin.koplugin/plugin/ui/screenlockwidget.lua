local _ = require("gettext")
local Font = require("ui/font")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local ButtonTable = require("ui/widget/buttontable")
local Screen = require("device").screen

local PinInputState = require("plugin/state/pininput")
local TextBoxLiteWidget = require("plugin/ui/textboxlitewidget")

local ScreenLockWidget = VerticalGroup:extend {
    ui_root = nil,
    state = nil,
    width_factor = 0.9,
    title_face = Font:getFace("smalltfont"),
}

function ScreenLockWidget:init()
    self.state = PinInputState:new {
        placeholder = _("Enter PIN"),
        size_factor = 2,
        on_display_update = self.on_display_update,
        on_display_update = function(text) if self[1] then self[1]:setText(text) end end,
        on_update = self.on_update,
    }
    local width = math.floor(Screen:getWidth() * self.width_factor)
    self[1] = TextBoxLiteWidget:new {
        ui_root = self.ui_root,
        text = self.state.display,
        face = self.title_face,
        width = width,
        padding = Size.item.height_default,
    }
    self[2] = ButtonTable:new {
        buttons = self.state:makeButtons(),
        width = width,
        zero_sep = true,
    }
end

function ScreenLockWidget:onScreenResize(screen_dimen)
    local width = math.floor(screen_dimen.w * self.width_factor)
    local textbox = self[1]
    local buttontable = self[2]
    buttontable.width = width
    buttontable.dimen = nil
    buttontable:free()
    buttontable:init()
    textbox:free(true)
    textbox.width = width
    self:resetLayout()
end

return ScreenLockWidget
