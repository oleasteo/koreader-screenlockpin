local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local ScreenLockWidget = require("plugin/ui/screenlockwidget")

local LockScreenFrame = FrameContainer:extend {
    name = "SLPLockScreen",

    widget = nil,
    on_unlock = nil,

    _refresh_region = nil,
}

function LockScreenFrame:init()
    self.widget = ScreenLockWidget:new {
        ui_root = self,
        on_update = function(input)
            if input ~= pluginSettings.readPin() then
                self.widget.state:incFailedCount()
                return
            end
            logger.dbg("ScreenLockPin: unlock")
            self.on_unlock()
        end
    }

    local content_container = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        padding = 0,
        self.widget,
    }

    self[1] = CenterContainer:new {
        dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()},
        content_container,
    }

    if self.background then self._refresh_region = self[1].dimen end
end

function LockScreenFrame:getRefreshRegion()
    if self._refresh_region then return self._refresh_region end
    if self.background then
        self._refresh_region = self[1].dimen
    else
        local content_size = self[1][1]:getSize()
        self._refresh_region = Geom:new {
            x = math.floor((Screen:getWidth() - content_size.w)/2),
            y = math.floor((Screen:getHeight() - content_size.h)/2),
            w = content_size.w,
            h = content_size.h,
        }
    end
    return self._refresh_region
end

function LockScreenFrame:clearInput()
    logger.dbg("ScreenLockPin: clear overlay input")
    self.widget.state:clear()
end

function LockScreenFrame:relayout(refreshmode)
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    logger.dbg("ScreenLockPin: resize overlay to " .. screen_dimen.x .. "x" .. screen_dimen.y)
    self[1].dimen = screen_dimen
    self.widget:onScreenResize(screen_dimen)
    self._refresh_region = nil
    UIManager:setDirty(self, refreshmode, self:getRefreshRegion())
end

return LockScreenFrame
