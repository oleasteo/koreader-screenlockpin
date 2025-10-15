local ButtonTable = require("ui/widget/buttontable")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local UIManager = require("ui/uimanager")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local _ = require("gettext")
local ScreenLockInput = require("screenlockinput")
--local Blitbuffer = require("ffi/blitbuffer")

local ScreenLockWidget = VerticalGroup:extend {
    fit = true,
    input = nil,
    title_face = Font:getFace("smalltfont"),
    centered_within = nil,
    container = nil,

    _clear_region = nil,
}

function ScreenLockWidget:init()
    self.input = ScreenLockInput:new {
        placeholder = _("Enter PIN"),
        size_factor = 2,
        on_display_update = self.on_display_update,
        on_display_update = function(__, text)
            local text_widget = self[1]
            if text_widget then
                local prev_clear_region = self._clear_region or self:calcTextRegion()
                text_widget:setText(text)
                text_widget:updateSize()
                -- re-center the text
                self:resetLayout()
                -- use performant method to clear text region
                if self.centered_within then
                    local next_clear_region = self:calcTextRegion()
                    UIManager:setDirty(self.container or "all", "fast", Geom.boundingBox({ prev_clear_region, next_clear_region }))
                    self._clear_region = next_clear_region
                else
                    UIManager:setDirty(self.container or "all", "fast")
                end
            end
        end,
        on_update = self.on_update,
    }
    self[1] = TextWidget:new {
        text = self.input.display,
        width_factor = 1.0,
        alignment = "center",
        face = self.title_face,
    }
    self[2] = VerticalSpan:new {
        width = Size.item.height_large * 2,
    }
    self[3] = ButtonTable:new {
        buttons = self.input:makeButtons(),
        shrink_unneeded_width = not self.fit,
        width_factor = self.fit and 1.0 or nil,
        zero_sep = true,
    }
end

function ScreenLockWidget:calcTextRegion()
    local center = {
        x = self.centered_within.x + self.centered_within.w / 2,
        y = self.centered_within.y + self.centered_within.h / 2,
    }
    local text_size = self[1]:getSize()
    local self_size = self:getSize()

    return {
        x = math.floor(center.x - text_size.w / 2),
        y = math.floor(center.y - self_size.h / 2),
        -- for some reason, the region isn't 100% accurate :/
        w = text_size.w + 10,
        h = text_size.h + 10,
    }
end

-- show clear region for debugging
--function ScreenLockWidget:paintTo(bb, x, y)
--    local dimen = self:calcTextRegion()
--    bb:paintRect(dimen.x, dimen.y, dimen.w, dimen.h, Blitbuffer.COLOR_GRAY_9)
--    VerticalGroup.paintTo(self, bb, x, y)
--end

return ScreenLockWidget
