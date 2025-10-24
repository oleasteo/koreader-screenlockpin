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
local ScreenLockDialog = require("ui/screenlockdialog")
local ScreenLockWidget = require("ui/screenlockwidget")
local Screen = Device.screen

-- migrate from 2025-10
if G_reader_settings:has("screenlockpin") then
    G_reader_settings:saveSetting("screenlockpin_pin", G_reader_settings:readSetting("screenlockpin"))
    G_reader_settings:delSetting("screenlockpin")
end

-- Default settings
if G_reader_settings:hasNot("screenlockpin_onboot") then
    G_reader_settings:makeFalse("screenlockpin_onboot")
end
if G_reader_settings:hasNot("screenlockpin_pin") then
    G_reader_settings:saveSetting("screenlockpin_pin", "0000")
end
if G_reader_settings:hasNot("screenlockpin_ratelimit") then
    -- this setting is not provided to the UI as it's highly recommended to have
    -- rate limiting enabled
    G_reader_settings:makeTrue("screenlockpin_ratelimit")
end

G_reader_settings:saveSetting("screenlockpin_version", "2025.10-1")

local ScreenLock = EventListener:extend {
    overlay = nil, -- Current active overlay
    dialog = nil, -- Current active dialog
}

function ScreenLock:init()
    Dispatcher:registerAction("screenlockpin_lock", {
        category = "none",
        event    = "LockScreen",
        title    = _("Lock screen"),
        device   = true,
    })
    self.ui.menu:registerToMainMenu(self)
end

function ScreenLock:addToMainMenu(menu_items)
    menu_items.screen_lockpin_reset = {
        sorting_hint = "screen",
        text = _("Lock screen"),
        sub_item_table = {
            {
                text = _("Lock on wakeup"),
                checked_func = function() return self:isEnabledOnResume() end,
                callback = function() self:toggleEnabledOnResume() end,
            },
            {
                text = _("Lock on boot"),
                checked_func = function() return G_reader_settings:isTrue("screenlockpin_onboot") end,
                callback = function() G_reader_settings:toggle("screenlockpin_onboot") end,
                separator = true,
            },
            {
                text = _("Change PIN"),
                callback = function() self:openUpdateDialog() end,
            },
        }
    }
end

-- monkey-patch the UIManager:run method, as we don't know a better way to do
-- very early startup code injection
local _run = UIManager.run
local function uiRunInjected(self)
    ScreenLock:onStart()
    return _run(self)
end
UIManager.run = uiRunInjected
logger.dbg("ScreenLockPin: Patched UIManager:run")

function ScreenLock:stopPlugin()
    -- restore UIManager:run
    UIManager.run = _run
    -- disable lock method
    self:disableOnResume()
    -- destroy options
    G_reader_settings:delSetting("screenlockpin_onboot")
    G_reader_settings:delSetting("screenlockpin_pin")
    return true
end

function ScreenLock:onStart()
    logger.dbg("ScreenLockPin: Checking for lock on boot")
    if not G_reader_settings:isTrue("screenlockpin_onboot") then return end
    UIManager:nextTick(function()
        logger.dbg("ScreenLockPin: Show lock on boot")
        self:onLockScreen()
    end)
end

function ScreenLock:onScreenResize()
    if self.overlay then self:resizeOverlay() end
end

function ScreenLock:onSetRotationMode(mode)
    if not self.overlay then return end
    local old_mode = Screen:getRotationMode()
    logger.dbg("ScreenLockPin: update rotation (" .. mode .. "; old: " .. old_mode .. ")")
    if mode ~= nil and mode ~= old_mode then
        Screen:setRotationMode(mode)
        self:resizeOverlay()
    end
end

function ScreenLock:onResume()
    if not self:isEnabledOnResume() then return end
    -- we hijack the screensaver_delay (property of ui/screensaver.lua)
    -- any unknown values will be interpreted as "tap to exit from screensaver"
    -- this enables us to create a lock screen first before closing the
    -- screensaver
    self:onLockScreen()
    Screensaver:close_widget()
end

function ScreenLock:onLockScreen()
    if self.overlay then
        self.overlay[1][1].state:reset()
        logger.dbg("ScreenLockPin: Overlay already present")
        return
    end
    logger.dbg("ScreenLockPin: Create screen overlay")
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    self.overlay = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        -- UIManager performance hint
        covers_fullscreen = true,
        disable_double_tap = true,
        -- handle rotation if not locked to orientation
        onSetRotationMode = function (_, mode) self:onSetRotationMode(mode) end,

        CenterContainer:new {
            dimen = screen_dimen,

            ScreenLockWidget:new {
                centered_within = screen_dimen,
                on_update = function(input)
                    if input ~= G_reader_settings:readSetting("screenlockpin_pin") then
                        self.overlay[1][1].state:incFailedCount()
                        return
                    end
                    logger.dbg("ScreenLockPin: Unlocked.")
                    UIManager:close(self.overlay, "ui")
                    self.overlay:free()
                    self.overlay = nil
                end
            }
        }
    }
    -- pass ScreenLockWidget the container reference for performant regional updates
    self.overlay[1][1].container = self.overlay
    UIManager:show(self.overlay)
end

function ScreenLock:resizeOverlay()
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    logger.dbg("ScreenLockPin: Resize Overlay " .. screen_dimen.x .. "x" .. screen_dimen.y)
    local framecontainer = self.overlay
    local centercontainer = framecontainer[1]
    centercontainer.dimen = screen_dimen
    local widget = centercontainer[1]
    widget:onScreenResize(screen_dimen)
    UIManager:setDirty(self.overlay, "ui")
end

function ScreenLock:openUpdateDialog()
    self.dialog = ScreenLockDialog:new {
        placeholder = _("Enter new PIN"),
        disable_double_tap = true,
        on_submit = function(next_pin)
            logger.dbg("ScreenLockPin: New PIN – " .. next_pin)
            G_reader_settings:saveSetting("screenlockpin_pin", next_pin)
            UIManager:show(InfoMessage:new { text = _("PIN changed successfully."), timeout = 1 })
            UIManager:close(self.dialog, "ui")
            self.dialog:free()
            self.dialog = nil
        end,
    }
    UIManager:show(self.dialog)
end

function ScreenLock:isEnabledOnResume()
    return G_reader_settings:readSetting("screensaver_delay") == "plugin:screenlockpin"
end

function ScreenLock:disableOnResume()
    if self:isEnabledOnResume() then
        local return_value = G_reader_settings:readSetting("screenlockpin_returndelay") or "disable"
        logger.dbg("ScreenLockPin: Disable ScreenLock to " .. return_value)
        G_reader_settings:saveSetting("screensaver_delay", return_value)
        return true
    end
    return false
end

function ScreenLock:toggleEnabledOnResume()
    if self:isEnabledOnResume() then
        self:disableOnResume()
    else
        G_reader_settings:saveSetting("screenlockpin_returndelay", G_reader_settings:readSetting("screensaver_delay"))
        G_reader_settings:saveSetting("screensaver_delay", "plugin:screenlockpin")
    end
end

return ScreenLock
