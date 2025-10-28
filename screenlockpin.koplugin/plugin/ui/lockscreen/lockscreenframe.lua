local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local ScreenLockWidget = require("plugin/ui/lockscreen/screenlockwidget")

local LockScreenFrame = WidgetContainer:extend {
    name = "SLPLockScreen",

    lock_widget = nil,
    on_unlock = nil,
    visible = true,
    -- a slightly grown refresh region seems to reduce ghosting a little
    clear_outset = Screen:scaleBySize(2),

    _refresh_region = nil,
    _content_region = nil,
}

function LockScreenFrame:init()
    self.lock_widget = ScreenLockWidget:new {
        ui_root = self,
        scale = 0.5,
        on_update = function(input)
            if input ~= pluginSettings.readPin() then
                self.lock_widget.state:incFailedCount()
                return
            end
            logger.dbg("ScreenLockPin: unlock")
            self.on_unlock()
        end
    }

    self[1] = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        -- half-bright gray border plays nice with most wallpapers and mitigates
        -- ghosting a little
        color = Blitbuffer.COLOR_GRAY_7,
        padding = 0,
        self.lock_widget,
    }
end

function LockScreenFrame:setVisible(bool)
    self.visible = bool
end

function LockScreenFrame:paintTo(bb, x, y)
    if not self.visible then return end
    local region = self:getContentRegion()
    self[1]:paintTo(bb, x + region.x, y + region.y)
end

function LockScreenFrame:getRefreshRegion()
    if self._refresh_region then return self._refresh_region end
    local content_size = self[1]:getSize()
    self._content_region = Geom:new {
        x = math.floor((Screen:getWidth() - content_size.w)/2),
        y = math.floor((Screen:getHeight() - content_size.h)/2),
        w = content_size.w,
        h = content_size.h,
    }
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
    logger.dbg("ScreenLockPin: resize overlay to " .. screen_dimen.x .. "x" .. screen_dimen.y)
    self[1].dimen = screen_dimen
    self.lock_widget:onScreenResize(screen_dimen)
    self._refresh_region = nil
    self._content_region = nil
    UIManager:setDirty(self, refreshmode, self:getRefreshRegion())
end

return LockScreenFrame
