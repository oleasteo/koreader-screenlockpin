local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local Screen = require("device").screen

local PinInputState = require("plugin/state/pininput")
local TextBoxLiteWidget = require("plugin/ui/textboxlitewidget")
local PinButtonTable = require("plugin/ui/lockscreen/pinbuttontable")

local COLS = 3

local ScreenLockWidget = VerticalGroup:extend {
    ui_root = nil,
    state = nil,
    title_font = "smalltfont",

    scale = 0.5, -- 0 (minimum) to 1 (maximum)
    max_width_factor = 0.9,
    min_item_width = Size.item.height_large * 1.75,
    min_item_height = Size.item.height_large,
    _width = nil,
}

function ScreenLockWidget:init()
    local scaling = self:_scaling(Screen:getWidth())
    self._width = scaling.width
    self.state = PinInputState:new {
        placeholder = _("Enter PIN"),
        on_display_update = self.on_display_update,
        on_display_update = function(text) if self[1] then self[1]:setText(text) end end,
        on_update = self.on_update,
    }
    self[1] = TextBoxLiteWidget:new {
        ui_root = self.ui_root,
        text = self.state.display,
        fgcolor = Blitbuffer.COLOR_GRAY_6,
        face = Font:getFace(self.title_font, scaling.display_font_size),
        width = scaling.width,
        padding = Size.item.height_default,
        box_padding = scaling.display_box_padding,
    }
    self[2] = PinButtonTable:new {
        state = self.state,
        font_size = scaling.font_size,
        size_factor = 0.85 + 1.15 * self.scale,
        width = scaling.width,
    }
end

function ScreenLockWidget:_scaling(full_width)
    local scale = math.max(0, math.min(1, self.scale))
    local max_item_width = math.floor(full_width / COLS * self.max_width_factor)
    local item_width = self.min_item_width + (max_item_width - self.min_item_width) * scale
    return {
        width = math.max(self.min_item_width * COLS, math.min(full_width, item_width * COLS)),
        font_size = math.floor(14 + scale * 12),
        display_font_size = math.floor(14 + scale * 10),
        display_box_padding = math.floor((Size.padding.large * 2) * scale),
    }
end

function ScreenLockWidget:onScreenResize(screen_dimen)
    local scaling = self:_scaling(screen_dimen.w)
    self._width = scaling.width
    local textbox = self[1]
    local buttontable = self[2]
    buttontable:rescale(scaling)
    textbox.box_padding = scaling.display_box_padding
    textbox:setWidth(scaling.width)
    textbox.face = Font:getFace(self.title_font, scaling.display_font_size)
    self:resetLayout()
end

return ScreenLockWidget
