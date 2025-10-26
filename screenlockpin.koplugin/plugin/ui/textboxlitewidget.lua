local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local TextWidget = require("ui/widget/textwidget")

--
-- A simple, center-aligned, one-line text box
--
local TextBoxLiteWidget = TextWidget:extend {
    -- mandatory
    ui_root = nil,
    width = nil,
    text = nil,

    -- optional overrides
    refreshtype = "fast",
    fgcolor = Blitbuffer.COLOR_BLACK,
    bgcolor = Blitbuffer.COLOR_WHITE,
    box_padding = Size.padding.large,
    face = Font:getFace("smalltfont"),

    -- defaults for TextWidget
    padding = 0,

    -- cached relative dimensions of text box
    _dimen = nil,
    -- absolute center coordinates of last painted bounds
    _center_abs = nil,
    -- absolute region of last painted text (minimal text bounds)
    _text_region_abs = nil,
}

function TextBoxLiteWidget:init()
    self.max_width = self.width - 2 * self.box_padding
end

function TextBoxLiteWidget:setText(text)
    if not self._center_abs then
        -- no cached center => we haven't drawn anything yet
        TextWidget.setText(self, text)
        self:free()
        return
    end
    local center_abs = self._center_abs
    local prev_text_region = self._text_region_abs
    TextWidget.setText(self, text)
    self:free()
    local next_text_region = self:centerAlignedTextBounds(center_abs, TextWidget.getSize(self))
    local clear_region = Geom.boundingBox({ prev_text_region, next_text_region })
    UIManager:setDirty(self.ui_root, self.refreshtype, clear_region)
end

function TextBoxLiteWidget:getSize()
    if self._dimen then return self._dimen end
    local text_size = TextWidget.getSize(self)
    self._dimen = {
        w = self.width,
        h = text_size.h + self.box_padding * 2,
    }
    return self._dimen
end

function TextBoxLiteWidget:free()
    self._dimen = nil
    self._center_abs = nil
    self._text_region_abs = nil
    TextWidget.free(self)
end

function TextBoxLiteWidget:centerAlignedTextBounds(center_abs, text_size)
    return {
        x = center_abs.x - math.ceil(text_size.w / 2),
        y = center_abs.y - math.ceil(text_size.h / 2),
        w = text_size.w,
        h = text_size.h,
    }
end

function TextBoxLiteWidget:paintTo(bb, x, y)
    local dimen = self:getSize()
    bb:paintRect(x, y, dimen.w, dimen.h, self.bgcolor)
    self._center_abs = {
        x = x + math.floor(dimen.w / 2),
        y = y + math.floor(dimen.h / 2),
    }
    self._text_region_abs = self:centerAlignedTextBounds(self._center_abs, TextWidget.getSize(self))
    --bb:paintRect(self._text_region_abs.x, self._text_region_abs.y, self._text_region_abs.w, self._text_region_abs.h, Blitbuffer.COLOR_GRAY_9)
    TextWidget.paintTo(self, bb, self._text_region_abs.x, self._text_region_abs.y)
end

return TextBoxLiteWidget
