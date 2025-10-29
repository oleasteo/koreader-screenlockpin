local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local UIManager = require("ui/uimanager")
local Screensaver = require("ui/screensaver")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local screensaverUtil = require("plugin/util/screensaverutil")
local LockScreenFrame = require("plugin/ui/lockscreen/lockscreenframe")

local overlay

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
    overlay:setVisible(false)
    UIManager:setDirty("all", "full", overlay:getRefreshRegion())
end

local function reuseShowOverlay()
    logger.dbg("ScreenLockPin: clear & show lock")
    overlay:clearInput()
    overlay:setVisible(true)
    UIManager:setDirty(overlay, "full", overlay:getRefreshRegion())
end

local function onResume()
    if not pluginSettings.shouldLockOnWakeup() then return end
    if not overlay then return end
    Device.screen_saver_lock = true
    reuseShowOverlay()
end

local function showOrClearLockScreen(cause)
    if cause == "resume" and overlay then
        logger.dbg("ScreenLockPin: ignoring duplicate resume trigger")
        -- ignore duplicate resume (triggered by plugin:onResume), it's already
        -- been handled by widget:onResume (while overlay is shown)
        return
    end
    logger.dbg("ScreenLockPin: show lock screen (" .. cause .. ")")
    if overlay then return reuseShowOverlay() end
    logger.dbg("ScreenLockPin: create lock screen")
    screensaverUtil.freezeScreensaverAbi()
    overlay = LockScreenFrame:new {
        -- UIManager performance tweaks
        modal = true,
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

return {
    showOrClearLockScreen = showOrClearLockScreen,
}
