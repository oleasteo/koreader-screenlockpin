local _ = require("gettext")
local util = require("util")
local Font = require("ui/font")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local ButtonTable = require("ui/widget/buttontable")
local Notification = require("ui/widget/notification")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local logger = require("logger")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local PinInputState = require("plugin/state/pininput")
local PinButtonTable = require("plugin/ui/lockscreen/pinbuttontable")

local ChangePinDialog = InputContainer:extend {
    name = "SLPChangePinDialog",

    font_size = 16,
    size_factor = 1.25,

    title = "",
    title_align = "center",
    title_face = Font:getFace("smalltfont"),

    width_factor = 0.9,
    title_padding = Size.padding.large,
    title_margin = Size.margin.title,

    step = "ENTER_NEW",
    new_pin_candidate = nil,

    state = nil,
    titleWidget = nil,
    titleGroup = nil,
    dialogContent = nil,
    buttontable = nil,
    ges_events = nil,

    on_submit = nil,
    on_close = nil,

    key_events = {
        KbdNumber = { { { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" } } },
        KbdDel = {
            { "Ctrl", "Del" }, { "Shift", "Del" },
            { "Ctrl", "Backspace" }, { "Shift", "Backspace" },
            { { "Del", "Backspace" } },
        },
        KbdReturn = { { { "Press" } } },
    },
}

function ChangePinDialog:init()
    local ready = false
    local has_existing_pin = pluginSettings.hasPin()
    self.step = has_existing_pin and "VERIFY_CURRENT" or "ENTER_NEW"
    local initial_placeholder = has_existing_pin and _("Enter current PIN") or _("Enter new PIN")
    local initial_obfuscate = has_existing_pin

    self.state = PinInputState:new {
        placeholder = initial_placeholder,
        obfuscate = initial_obfuscate,
        on_submit = function(value)
            self:handleStepSubmit(value)
        end,
        on_update = self.on_update,
        on_display_update = function(title)
            if not ready then return end
            self:setTitle(title)
        end,
        on_valid_state = function(valid)
            if not ready then return end
            local submit = self:getButtonById("submit")
            if submit then
                if valid then submit:enable() else submit:disable() end
            end
        end,
    }

    local width = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * self.width_factor)

    if Device:hasKeys() then
        local back_group = util.tableDeepCopy(Device.input.group.Back)
        table.insert(back_group, "Escape")
        if Device:hasFewKeys() then
            table.insert(back_group, "Left")
            self.key_events.Close = { { back_group } }
        else
            table.insert(back_group, "Menu")
            self.key_events.Close = { { back_group } }
        end
    else
        self.key_events.Close = { { "Escape" } }
    end

    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new { ges = "tap", range = Screen:getSize() }
        }
    end

    self.buttontable = ButtonTable:new {
        buttons = PinButtonTable.makeButtonTemplates(self),
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

function ChangePinDialog:handleStepSubmit(value)
    if not self.state.valid then
        Notification:notify(_("PIN must have at least three digits."), Notification.SOURCE_DISPATCHER)
        return
    end

    if self.step == "VERIFY_CURRENT" then
        local current_pin = pluginSettings.readPin()
        if current_pin ~= nil and value ~= current_pin then
            logger.dbg("ScreenLockPin: incorrect current PIN in dialog")
            self.state:incFailedCount()
            Notification:notify(_("Incorrect current PIN."), Notification.SOURCE_DISPATCHER)
            self.state:clearWithError(_("Incorrect current PIN"))
            return
        end
        self.step = "ENTER_NEW"
        self.state.placeholder = _("Enter new PIN")
        self.state.obfuscate = false
        self.state:clear()

    elseif self.step == "ENTER_NEW" then
        self.new_pin_candidate = value
        self.step = "CONFIRM_NEW"
        self.state.placeholder = _("Confirm new PIN")
        self.state.obfuscate = false
        self.state:clear()

    elseif self.step == "CONFIRM_NEW" then
        if value ~= self.new_pin_candidate then
            logger.dbg("ScreenLockPin: PIN confirmation mismatch in dialog")
            Notification:notify(_("PINs do not match. Please try again."), Notification.SOURCE_DISPATCHER)
            self.new_pin_candidate = nil
            self.step = "ENTER_NEW"
            self.state.placeholder = _("Enter new PIN")
            self.state.obfuscate = false
            self.state:clearWithError(_("PINs do not match"))
            return
        end
        if self.on_submit then
            self.on_submit(value)
        end
    end
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

function ChangePinDialog:onKbdNumber(_, evt)
    self.state:appendInput(evt.key)
end

function ChangePinDialog:onKbdDel(_, evt)
    self.state:delInput(evt.Ctrl or evt.Shift)
end

function ChangePinDialog:onKbdReturn()
    self:handleStepSubmit(self.state.value)
end

function ChangePinDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1][1].dimen
    end)
end

function ChangePinDialog:onClose()
    self.on_close()
    return true
end

function ChangePinDialog:onTapClose(_, ges)
    if ges.pos:notIntersectWith(self[1][1].dimen) then
        self:onClose()
    end
    return true
end

return ChangePinDialog
