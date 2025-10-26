local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local UIManager = require("ui/uimanager")
local Screensaver = require("ui/screensaver")
local Notification = require("ui/widget/notification")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local screensaverUtil = require("plugin/util/screensaverutil")
local uiManagerUtil = require("plugin/util/uimanagerutil")
local ChangePinDialog = require("plugin/ui/changepindialog")
local LockScreenFrame = require("plugin/ui/lockscreenframe")

local overlay
local dialog

local function relayout(refreshmode)
    overlay:relayout(nil)
    if Screensaver.screensaver_widget then
        Screensaver.screensaver_widget:update()
    end
    UIManager:setDirty("all", refreshmode)
end

local function onSetRotationMode(_, mode)
    if not overlay then return end
    local old_mode = Screen:getRotationMode()
    if mode ~= nil and mode ~= old_mode then
        logger.dbg("ScreenLockPin: update rotation from " .. old_mode .. " to " .. mode)
        Screen:setRotationMode(mode)
        relayout("full")
    end
end

local function onScreenResize()
    if not overlay then return end
    logger.dbg("ScreenLockPin: handle screen resize")
    relayout("full")
end

local function closeLockScreen()
    if not overlay then return end
    logger.dbg("ScreenLockPin: close lock screen")
    screensaverUtil.unfreezeScreensaverAbi()
    screensaverUtil.totalCleanup()
    UIManager:close(overlay, "full", overlay:getRefreshRegion())
    overlay = nil
end

local function onSuspend()
    if not overlay then return end
    Device.screen_saver_lock = false
    local widget = Screensaver.screensaver_widget
    if not widget then return end
    uiManagerUtil.pullModalToFront(widget, nil)
    UIManager:setDirty(widget, "full", overlay:getRefreshRegion())
end

local function onResume()
    if not pluginSettings.shouldLockOnWakeup() then return end
    if not overlay then return end
    Device.screen_saver_lock = true
    logger.dbg("ScreenLockPin: refresh lock on resume")
    overlay:clearInput()
    uiManagerUtil.pullModalToFront(overlay, nil)
    UIManager:setDirty(overlay, "full", overlay:getRefreshRegion())
end

local function showOrClearLockScreen(cause)
    if cause == "resume" and overlay then
        logger.dbg("ScreenLockPin: ignoring duplicate resume trigger")
        -- ignore duplicate resume (triggered by plugin:onResume), it's already
        -- been handled by widget:onResume (while overlay is shown)
        return
    end
    logger.dbg("ScreenLockPin: show lock screen (" .. cause .. ")")
    if overlay then
        logger.dbg("ScreenLockPin: pull lock screen in front")
        overlay:clearInput()
        uiManagerUtil.pullModalToFront(overlay, "full")
        return
    end
    logger.dbg("ScreenLockPin: create lock screen")
    screensaverUtil.freezeScreensaverAbi()
    overlay = LockScreenFrame:new {
        -- UIManager performance tweaks
        modal = true,
        covers_fullscreen = pluginSettings.isUiOpaque(),
        disable_double_tap = true,
        -- UIManager hook (called on ui root elements): handle rotation if not locked to orientation
        onSetRotationMode = onSetRotationMode,
        -- UIManager hook (called on ui root elements)
        onScreenResize = onScreenResize,
        -- UIManager hook (called on ui root elements)
        onSuspend = onSuspend,
        -- UIManager hook (called on ui root elements)
        onResume = onResume,
        -- LockScreenFrame
        on_unlock = closeLockScreen,
    }
    UIManager:show(overlay, "full", overlay:getRefreshRegion())
end

local function closeChangePinDialog()
    if not dialog then return end
    logger.dbg("ScreenLockPin: close change PIN dialog")
    UIManager:close(dialog, "ui")
    dialog = nil
end

local function showChangePinDialog()
    if dialog then return end
    logger.dbg("ScreenLockPin: create change PIN dialog")
    dialog = ChangePinDialog:new {
        -- UIManager performance tweak
        disable_double_tap = true,
        -- ChangePinDialog
        on_submit = function(next_pin)
            pluginSettings.setPin(next_pin)
            closeChangePinDialog()
            UIManager:nextTick(function()
                Notification:notify(_("PIN changed."), Notification.SOURCE_DISPATCHER)
            end)
        end,
    }
    UIManager:show(dialog)
end

return {
    showOrClearLockScreen = showOrClearLockScreen,
    showChangePinDialog = showChangePinDialog,
}
