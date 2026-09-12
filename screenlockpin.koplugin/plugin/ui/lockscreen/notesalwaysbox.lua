local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local GestureRange = require("ui/gesturerange")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")

local NotesAlwaysBox = InputContainer:extend {
    name = "SLPNotesAlwaysBox",
    ui_root = nil,
    width = nil,
    text = nil,
    padding_x = nil,
    padding_y = nil,
    font_size = nil,
    on_tap = nil,
    visible_lines = 5,
}

function NotesAlwaysBox:init()
    if Device:isTouchDevice() then
        -- use a function to adapt to screen resize
        local range = function () return self:getSize() end
        self.ges_events.Tap = { GestureRange:new{ ges = "tap", range = range } };
    end

    local text = self.text or _("No note configured.");
    local face = Font:getFace("smallinfofont", self.font_size);
    local textbox = TextBoxWidget:new {
        dialog = self.ui_root,
        text = text,
        height = 0,
        height_overflow_show_ellipsis = true,
        face = face,
        width = self.width - 2 * self.padding_x,
    };
    local show_lines = #textbox.vertical_string_list >= self.visible_lines
            and self.visible_lines
            or #textbox.vertical_string_list;
    textbox.height = textbox:getLineHeight() * show_lines;
    -- re-init to refresh lines_per_page and line_with_ellipsis
    textbox.line_with_ellipsis = nil;
    textbox:init();

    table.insert(self, FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        color = Blitbuffer.COLOR_GRAY_7,
        padding_top = self.padding_y,
        padding_bottom = self.padding_y,
        padding_left = self.padding_x,
        padding_right = self.padding_x,

        textbox,
    });
end

function NotesAlwaysBox:onTap()
    self.on_tap();
    -- consume event
    return true;
end

function NotesAlwaysBox:setWidth(width)
    self.width = width;
    -- InputContainer caches dimensions
    self.dimen = nil;
    -- FrameContainer caches dimensions
    self[1].dimen = nil;
    self[1][1].width = self.width - 2 * self.padding_x;
    self[1][1]:update();
end

return NotesAlwaysBox;
