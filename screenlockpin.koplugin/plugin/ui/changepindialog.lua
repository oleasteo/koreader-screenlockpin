local _ = require("gettext")
local util = require("util")
local Font = require("ui/font")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local FocusManager = require("ui/widget/focusmanager")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local Screen = Device.screen

local PinInputState = require("plugin/state/pininput")

local ChangePinDialog = FocusManager:extend {
    name = "SLPChangePinDialog",

    size_factor = 1.25,

    title = "",
    title_align = "center",
    title_face = Font:getFace("smalltfont"),

    width_factor = 0.9,
    title_padding = Size.padding.large,
    title_margin = Size.margin.title,

    state = nil,
    titleWidget = nil,
    titleGroup = nil,
    dialogContent = nil,
    buttontable = nil,
    key_events = nil,
    ges_events = nil,
}

function ChangePinDialog:init()
    local ready = false
    self.state = PinInputState:new {
        placeholder = _("Enter new PIN"),
        size_factor = self.size_factor,
        on_submit = self.on_submit,
        on_update = self.on_update,
        on_display_update = function(title)
            if not ready then return end
            self:setTitle(title)
        end,
        on_valid_state = function(valid)
            if not ready then return end
            local submit = self:getButtonById("submit")
            if valid then submit:enable() else submit:disable() end
        end,
    }

    local width = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * self.width_factor)

    if Device:hasKeys() then
        local back_group = util.tableDeepCopy(Device.input.group.Back)
        if Device:hasFewKeys() then
            table.insert(back_group, "Left")
            self.key_events.Close = { { back_group } }
        else
            table.insert(back_group, "Menu")
            self.key_events.Close = { { back_group } }
        end
    end

    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new { ges = "tap", range = Screen:getSize() }
        }
    end

    self.buttontable = ButtonTable:new {
        buttons = self.state:makeButtons(),
        width = width - 2 * Size.border.window - 2 * Size.padding.button,
    }
    local buttontable_width = self.buttontable:getSize().w

    local title_padding = Size.padding.default
    local title_margin = Size.margin.default

    self.layout = self.buttontable.layout
    self.buttontable.layout = nil

    self.titleWidget = TextWidget:new {
        text = self.state.display,
        width = buttontable_width - 2 * (title_padding + title_margin),
        face = self.title_face,
        bold = true,
    }
    self.titleGroup = VerticalGroup:new {
        align = self.title_align,
        self.titleWidget,
    }
    self.dialogContent = VerticalGroup:new {
        FrameContainer:new {
            padding = title_padding,
            padding_top = title_padding * 2,
            padding_bottom = title_padding * 2,
            margin = title_margin,
            bordersize = 0,
            self.titleGroup
        },
        LineWidget:new {
            background = Blitbuffer.COLOR_GRAY,
            dimen = Geom:new { w = buttontable_width, h = Size.line.medium },
        },
        self.buttontable,
    }
    self[1] = CenterContainer:new {
        dimen = Screen:getSize(),
        FrameContainer:new {
            background = Blitbuffer.COLOR_WHITE,
            bordersize = Size.border.window,
            radius = Size.radius.window,
            padding = Size.padding.button,
            padding_top = 0,
            padding_bottom = 0,
            self.dialogContent,
        },
    }

    ready = true
end

function ChangePinDialog:getButtonById(id)
    return self.buttontable:getButtonById(id)
end

function ChangePinDialog:setTitle(title)
    self.titleWidget:setText(title)
    self.titleWidget:updateSize()
    self.titleGroup:resetLayout()
    self.dialogContent:resetLayout()
    UIManager:setDirty(self, "fast")
end

function ChangePinDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1][1].dimen
    end)
end

function ChangePinDialog:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "flashui", self[1][1].dimen
    end)
end

function ChangePinDialog:onClose()
    UIManager:close(self)
    return true
end

function ChangePinDialog:onTapClose(_, ges)
    if ges.pos:notIntersectWith(self[1][1].dimen) then
        self:onClose()
    end
    return true
end

return ChangePinDialog
