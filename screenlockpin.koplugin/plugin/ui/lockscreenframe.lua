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
    widget = nil,
    on_unlock = nil,
}

function LockScreenFrame:init()
    self.background = pluginSettings.isUiOpaque() and Blitbuffer.COLOR_WHITE or nil

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
    UIManager:setDirty(self, refreshmode)
end

return LockScreenFrame
