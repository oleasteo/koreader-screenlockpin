local logger = require("logger")
local Dispatcher = require("dispatcher")
local Device = require("device")
local Geom = require("ui/geometry")
local Blitbuffer = require("ffi/blitbuffer")
local UIManager = require("ui/uimanager")
local Screensaver = require("ui/screensaver")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local EventListener = require("ui/widget/eventlistener")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local ScreenLockDialog = require("screenlockdialog")
local ScreenLockWidget = require("screenlockwidget")
local Screen = Device.screen

local ScreenLock = EventListener:extend {
    overlay = nil, -- Current active overlay
    dialog = nil, -- Current active dialog
}

function ScreenLock:init()
    Dispatcher:registerAction("screenlockpin_lock", {
        category = "none",
        event    = "LockScreen",
        title    = _("Lock Screen"),
        device   = true,
    })
    self.ui.menu:registerToMainMenu(self)
end

function ScreenLock:addToMainMenu(menu_items)
    menu_items.screen_lockpin_reset = {
        text = _("ScreenLock PIN"),
        callback = function() self:openUpdateDialog() end
    }
end

function ScreenLock:storedPin()
    local pin = G_reader_settings:readSetting("screenlockpin")
    return pin or "0000"
end

function ScreenLock:onResume()
    -- we hijack the screensaver_delay (property of ui/screensaver.lua)
    -- any unknown values will be interpreted as "tap to exit from screensaver"
    -- this enables us to create a lock screen first before closing the
    -- screensaver
    local lock_method = G_reader_settings:readSetting("screensaver_delay")
    if lock_method == "plugin:screenlockpin" then
        self:onLockScreen()
        Screensaver:close_widget()
    end
end

function ScreenLock:onLockScreen()
    if self.overlay then
        self.overlay[1][1].input:reset()
        logger.dbg("ScreenLockPin: Overlay already present")
        return
    end
    logger.dbg("ScreenLockPin: Create screen overlay")
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    self.overlay = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
        -- UIManager performance hint
        covers_fullscreen = true,

        CenterContainer:new {
            dimen = screen_dimen,

            ScreenLockWidget:new {
                centered_within = screen_dimen,
                on_update = function(__, input)
                    if input == self:storedPin() then
                        logger.dbg("ScreenLockPin: Unlocked.")
                        UIManager:close(self.overlay, "ui")
                        self.overlay:free()
                        self.overlay = nil
                        return
                    end
                end
            }
        }
    }
    -- pass ScreenLockWidget the container reference for performant regional updates
    self.overlay[1][1].container = self.overlay
    UIManager:show(self.overlay)
end

function ScreenLock:openUpdateDialog()
    self.dialog = ScreenLockDialog:new {
        placeholder = _("Enter new PIN"),

        on_submit = function(__, next_pin)
            logger.dbg("ScreenLockPin: New PIN – " .. next_pin)
            G_reader_settings:saveSetting("screenlockpin", next_pin)
            G_reader_settings:saveSetting("screensaver_delay", "plugin:screenlockpin")
            UIManager:show(InfoMessage:new { text = _("PIN changed successfully."), timeout = 1 })
            self.dialog:dispose()
            self.dialog = nil
        end,

        on_disable = function()
            self.dialog:dispose()
            self.dialog = nil
            local prev_value = G_reader_settings:readSetting("screensaver_delay")
            if prev_value == "plugin:screenlockpin" then
                logger.dbg("ScreenLockPin: Disable ScreenLock")
                G_reader_settings:saveSetting("screensaver_delay", "disable")
                UIManager:show(InfoMessage:new { text = _("ScreenLock disabled."), timeout = 1 })
            end
        end,
    }
end

return ScreenLock
