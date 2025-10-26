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
    margin = 0,
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
    local width = math.floor(Screen:getWidth() * self.width_factor) - 2 * self.margin
    self[1] = TextBoxLiteWidget:new {
        ui_root = self.ui_root,
        text = self.state.display,
        face = self.title_face,
        width = width,
        padding = math.max(Size.item.height_default, self.margin),
    }
    self[2] = ButtonTable:new {
        buttons = self.state:makeButtons(),
        width = width,
        zero_sep = true,
    }
end

function ScreenLockWidget:onScreenResize(screen_dimen)
    local width = math.floor(screen_dimen.w * self.width_factor) - 2 * self.margin
    local textbox = self[1]
    local buttontable = self[2]
    buttontable.width = width
    buttontable.dimen = nil
    buttontable:free()
    buttontable:init()
    textbox:free()
    textbox.width = width
    self:resetLayout()
end

function ScreenLockWidget:paintTo(bb, x, y)
    VerticalGroup.paintTo(self, bb, x, y + self.margin)
end

function ScreenLockWidget:getSize()
    local content_size = VerticalGroup.getSize(self)
    return {
        w = content_size.w + 2 * self.margin,
        h = content_size.h + self.margin,
    }
end

return ScreenLockWidget
