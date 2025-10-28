local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local ButtonTable = require("ui/widget/buttontable")
local Screen = require("device").screen

local PinInputState = require("plugin/state/pininput")
local TextBoxLiteWidget = require("plugin/ui/textboxlitewidget")

local COLS = 3

local ScreenLockWidget = VerticalGroup:extend {
    ui_root = nil,
    state = nil,
    title_font = "smalltfont",

    scale = 0.5, -- 0 (minimum) to 1 (maximum)
    max_width_factor = 0.9,
    min_item_width = Size.item.height_large * 2.5,
    min_item_height = Size.item.height_large,
}

function ScreenLockWidget:init()
    local scaling = self:scaling(Screen:getWidth())
    self.state = PinInputState:new {
        placeholder = _("Enter PIN"),
        size_factor = 1 + self.scale,
        font_size = scaling.font_size,
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
    self[2] = ButtonTable:new {
        buttons = self.state:makeButtons(),
        width = scaling.width,
        zero_sep = true,
    }
end

function ScreenLockWidget:scaling(full_width)
    local scale = math.max(0, math.min(1, self.scale))
    local max_item_width = math.floor(full_width / COLS * self.max_width_factor)
    local item_with = self.min_item_width + (max_item_width - self.min_item_width) * scale
    return {
        width = math.max(self.min_item_width * COLS, math.min(full_width, item_with * COLS)),
        font_size = 16 + scale * 10,
        display_font_size = 14 + scale * 8,
        display_box_padding = (Size.padding.large * 2.5) * scale,
    }
end

function ScreenLockWidget:onScreenResize(screen_dimen)
    local scaling = self:scaling(screen_dimen.w)
    local textbox = self[1]
    local buttontable = self[2]
    buttontable.width = scaling.width
    buttontable.dimen = nil
    -- todo update buttons font size & input state size factor
    buttontable:free()
    buttontable:init()
    textbox:free(true)
    textbox.width = scaling.width
    textbox.face = Font:getFace(self.title_font, scaling.display_font_size)
    textbox.box_padding = scaling.display_box_padding
    self:resetLayout()
end

return ScreenLockWidget
