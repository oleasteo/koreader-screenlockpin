local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local VerticalSpan = require("ui/widget/verticalspan")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconButton = require("ui/widget/iconbutton")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local OutsideAreaInput = require("plugin/ui/lockscreen/outsideareainput")
local HorizontalFlexGroup = require("plugin/ui/horizontalflexgroup")
local ScreenLockWidget = require("plugin/ui/lockscreen/screenlockwidget")
local LockScreenStatusText = require("plugin/ui/lockscreen/statustext")
local NotesAlwaysBox = require("plugin/ui/lockscreen/notesalwaysbox")

local LockScreenFrame = InputContainer:extend {
    name = "SLPLockScreen",

    lock_widget = nil,
    status_text = nil,
    bottom_row = nil,
    on_unlock = nil,
    on_notes_overlay = nil,
    visible = true,
    -- a slightly grown refresh region seems to reduce ghosting a little
    clear_outset = Screen:scaleBySize(2),

    _refresh_region = nil,
    _content_region = nil,
    outside_input = nil,

    vgroup = nil,
    notes_always = nil,
    lockpanel_vgroup = nil,

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

function LockScreenFrame:init()
    local uiSettings = pluginSettings.getUiSettings()
    local scale = uiSettings.scale / 100
    self.lock_widget = ScreenLockWidget:new {
        ui_root = self,
        scale = scale,
        on_update = function(input)
            local pin = pluginSettings.readPin()
            if pin == nil then return end
            if input == pin then
                logger.dbg("ScreenLockPin: unlock")
                self.on_unlock()
                return
            end
            if #input >= #pin or #input >= 12 then
                logger.dbg("ScreenLockPin: incorrect PIN entered")
                self.lock_widget.state:incFailedCount()
                if not (self.lock_widget.state.throttle and self.lock_widget.state.throttle:isPaused()) then
                    self.lock_widget.state:clearWithError(_("Incorrect PIN"))
                end
            end
        end
    }
    self.status_text = LockScreenStatusText:new {
        font_size = 13 + math.floor(scale * 7.1),
        on_change = function ()
            if not self.bottom_row then return end
            self:_resetStatusTextLayout()
            UIManager:setDirty(self, "fast", self:getRefreshRegion())
        end,
    }

    local note_cfg = pluginSettings.getNoteSettings()
    local action_buttons = WidgetContainer:new {}
    local icon_padding = math.floor(Size.padding.large * (0.2 + scale))
    if note_cfg.mode == "button" then
        local icon_size = math.floor(Size.item.height_big * (0.75 + scale))
        table.insert(action_buttons, IconButton:new {
            icon = "appbar.typeset",
            width = icon_size,
            height = icon_size,
            callback = self.on_notes_overlay,
            allow_flash = false,
            padding = icon_padding,
        })
    end

    self.bottom_row = HorizontalFlexGroup:new {
        width = self.lock_widget._width,
        padding = math.floor(Size.padding.large * (0.2 + scale)),
        -- for small panels, the center-align with action buttons looks better,
        -- for big panels, the bottom align looks more adequate
        align = #action_buttons > 0 and uiSettings.scale > 33 and "bottom" or "center",

        action_buttons,
        VerticalGroup:new {
            VerticalSpan:new { width = icon_padding },
            HorizontalGroup:new {
                self.status_text,
                -- add padding to the right for symmetry with action icon paddings
                HorizontalSpan:new { width = icon_padding },
            },
            VerticalSpan:new { width = icon_padding },
        }
    }

    self.outside_input = OutsideAreaInput:new {
        content_region = nil,
    }
    self.lockpanel_vgroup = VerticalGroup:new { self.lock_widget, self.bottom_row }
    self.vgroup = VerticalGroup:new { }

    local lockframe = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        -- half-bright gray border plays nice with most wallpapers and mitigates
        -- ghosting a little
        color = Blitbuffer.COLOR_GRAY_7,
        padding = 0,

        self.lockpanel_vgroup
    };
    local spacing = math.floor(Size.padding.large * (1 + 3 * scale))
    if note_cfg.mode == "below" or note_cfg.mode == "above" then
        self.notes_always = NotesAlwaysBox:new {
            ui_root = self,
            width = self.lock_widget._width,
            padding_x = spacing,
            padding_y = spacing * 0.8,
            font_size = math.floor(16 + 8 * scale),
            text = note_cfg.preview_text ~= "" and note_cfg.preview_text or note_cfg.text,
            on_tap = self.on_notes_overlay
        };
    end
    if note_cfg.mode == "above" then
        table.insert(self.vgroup, self.notes_always)
        table.insert(self.vgroup, VerticalSpan:new { width = spacing })
        table.insert(self.vgroup, lockframe)
    elseif note_cfg.mode == "below" then
        table.insert(self.vgroup, lockframe)
        table.insert(self.vgroup, VerticalSpan:new { width = spacing })
        table.insert(self.vgroup, self.notes_always)
    else
        table.insert(self.vgroup, lockframe)
    end

    table.insert(self, self.outside_input)
    table.insert(self, self.vgroup)
end

function LockScreenFrame:onKbdNumber(_, evt)
    self.lock_widget.state:appendInput(evt.key)
end

function LockScreenFrame:onKbdDel(_, evt)
    self.lock_widget.state:delInput(evt.Ctrl or evt.Shift)
end

function LockScreenFrame:onKbdReturn()
    local pin = pluginSettings.readPin()
    if pin == nil then return end
    local input = self.lock_widget.state.value
    if input == pin then
        logger.dbg("ScreenLockPin: unlock via Return")
        self.on_unlock()
    else
        logger.dbg("ScreenLockPin: incorrect PIN on Return")
        self.lock_widget.state:incFailedCount()
        if not (self.lock_widget.state.throttle and self.lock_widget.state.throttle:isPaused()) then
            self.lock_widget.state:clearWithError(_("Incorrect PIN"))
        end
    end
end

function LockScreenFrame:_resetStatusTextLayout()
    -- horizontal group
    self.bottom_row[2][2]:resetLayout()
    -- vertical group
    self.bottom_row[2]:resetLayout()
    -- horizontal flex group
    self.bottom_row:resetLayout()
end

function LockScreenFrame:setVisible(bool)
    if self.visible == bool then return end
    self.visible = bool
    if bool then
        self.status_text:resume()
    else
        self.status_text:pause()
    end
end

function LockScreenFrame:paintTo(bb, x, y)
    if not self.visible then return end
    if not Device:supportsScreensaver() then
        bb:paintRect(x, y, Screen:getWidth(), Screen:getHeight(), Blitbuffer.COLOR_GRAY_E)
    end
    local region = self:getContentRegion()
    self.vgroup:paintTo(bb, x + region.x, y + region.y)
    --debug content position
    --bb:paintRect(x + region.x, y + region.y, region.w, region.h, Blitbuffer.COLOR_GRAY_4)
end

function LockScreenFrame:getRefreshRegion()
    if self._refresh_region then return self._refresh_region end
    local content_size = self.vgroup:getSize()
    local uiSettings = pluginSettings.getUiSettings()
    local pos_x = uiSettings.pos_x / 100
    local pos_y = uiSettings.pos_y / 100
    if pos_x < 0 then pos_x = 0 elseif pos_x > 1 then pos_x = 1 end
    if pos_y < 0 then pos_y = 0 elseif pos_y > 1 then pos_y = 1 end
    local avail_w = math.max(0, Screen:getWidth() - content_size.w)
    local avail_h = math.max(0, Screen:getHeight() - content_size.h)
    local x = math.floor(avail_w * pos_x)
    local y = math.floor(avail_h * pos_y)

    self._content_region = Geom:new {
        x = x,
        y = y,
        w = content_size.w,
        h = content_size.h,
    }
    self.outside_input.content_region = self._content_region
    self._refresh_region = Geom:new {
        x = math.max(0, self._content_region.x - self.clear_outset),
        y = math.max(0, self._content_region.y - self.clear_outset),
        w = math.min(Screen:getWidth(), content_size.w + self.clear_outset * 2),
        h = math.min(Screen:getHeight(), content_size.h + self.clear_outset * 2),
    }
    return self._refresh_region
end

function LockScreenFrame:getContentRegion()
    self:getRefreshRegion()
    return self._content_region
end

function LockScreenFrame:clearInput()
    logger.dbg("ScreenLockPin: clear overlay input")
    self.lock_widget.state:clear()
end

function LockScreenFrame:relayout(refreshmode)
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    logger.dbg("ScreenLockPin: resize overlay (screen: " .. screen_dimen.w .. "x" .. screen_dimen.h .. ")")
    self.lock_widget:onScreenResize(screen_dimen)
    self.bottom_row:setWidth(self.lock_widget._width)
    if self.notes_always ~= nil then self.notes_always:setWidth(self.lock_widget._width) end
    self.outside_input.screen_mid = screen_dimen.h / 2
    self._refresh_region = nil
    self._content_region = nil
    self.lockpanel_vgroup:resetLayout()
    self.vgroup:resetLayout()
    UIManager:setDirty(self, refreshmode, self:getRefreshRegion())
end

function LockScreenFrame:onFrontlightStateChanged() self.status_text:onFrontlightStateChanged() end
function LockScreenFrame:onCharging() self.status_text:onCharging() end
function LockScreenFrame:onNotCharging() self.status_text:onNotCharging() end

return LockScreenFrame
