local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local ffiutil = require("ffi/util")
local PluginShare = require("pluginshare")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local Screensaver = require("ui/screensaver")
local InfoMessage = require("ui/widget/infomessage")
local Screen = Device.screen
local T = ffiutil.template

local pluginSettings = require("plugin/settings")
local screensaverUtil = require("plugin/util/screensaverutil")
local screenshoterUtil = require("plugin/util/screenshoterutil")
local uiManagerUtil = require("plugin/util/uimanagerutil")
local NotesFrame = require("plugin/ui/lockscreen/notesframe")
local LockScreenFrame = require("plugin/ui/lockscreen/lockscreenframe")

local overlay
local notes

local function relayout(refreshmode)
    overlay:relayout(nil)
    if Screensaver.screensaver_widget then
        if Screensaver.screensaver_widget.update then
            -- KOReader up to 2025.10
            Screensaver.screensaver_widget:update()
        else
            Screensaver.screensaver_widget:init()
        end
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

local function formatAttempts()
    local attempts_by_length = pluginSettings.readPersistentCache("attempts_by_length") or {}
    local str = ""
    for len, attempts in pairs(attempts_by_length) do
        if str ~= "" then str = str .. "\n" end
        local line = "  " .. T(_("Length %1: %2 attempts"), len, attempts)
        str = str .. line
    end
    return str
end

local function unlockScreen(cause)
    if not overlay then return false end
    logger.dbg("ScreenLockPin: close lock screen (" .. cause .. ")")
    screensaverUtil.unfreezeScreensaverAbi()
    -- decide upon refresh type depending on if we unlock to reader UI
    local hasReaderUi = uiManagerUtil.findTopMostWidget(function(widget)
        return getmetatable(widget).__index == ReaderUI
    end) ~= nil
    if hasReaderUi then
        logger.dbg("ScreenLockPin: Reader detected; full refresh")
        screensaverUtil.totalCleanup()
        UIManager:close(overlay)
        UIManager:setDirty("all", "full")
    else
        logger.dbg("ScreenLockPin: No reader detected; partial refresh should suffice")
        screensaverUtil.totalCleanup("flashui")
        UIManager:close(overlay, "flashui", overlay:getRefreshRegion())
    end
    screenshoterUtil.unfreezeScreenshoterAbi()
    overlay:free()
    overlay = nil
    local throttled_times = pluginSettings.readPersistentCache("throttled_times") or 0
    if throttled_times >= 2 then
        UIManager:show(InfoMessage:new{
            text = T(_("Caution!\nHigh amount of failed PIN inputs detected.\n%1"), formatAttempts()),
            icon = "notice-warning",
        })
        pluginSettings.putPersistentCache("throttled_times", 0)
        pluginSettings.putPersistentCache("attempts_by_length", nil)
    end
    UIManager:nextTick(PluginShare.plugin_updater_v1.ping)
    return true
end

local function onSuspend()
    if notes then
        UIManager:close(notes)
        notes = nil
    end
    if not overlay then return end
    Device.screen_saver_lock = false
    overlay:setVisible(false)
    UIManager:setDirty("all", "full", overlay:getRefreshRegion())
end

local function reuseShowOverlay()
    logger.dbg("ScreenLockPin: clear & show lock")
    overlay:clearInput()
    overlay:setVisible(true)
    UIManager:setDirty(overlay, "flashui", overlay:getRefreshRegion())
end

local function onResume()
    if not overlay then return end
    if not pluginSettings.getEnabled() then
        unlockScreen("plugin_disabled")
        return
    end
    Device.screen_saver_lock = true
    reuseShowOverlay()
end

local function showNotes()
    if notes or not overlay then return end
    local text = pluginSettings.getNoteSettings().text or _("No note configured.")
    local scale = pluginSettings.getUiSettings().scale / 100
    notes = NotesFrame:new {
        text = text,
        region = overlay._content_region,
        scale = scale,
        on_close = function()
            UIManager:close(notes, "ui", notes.region)
            notes = nil
        end
    }
    UIManager:show(notes, "ui", notes.region)
end

--- In case of translucent image wallpapers, we need to drop the
--- `covers_fullscreen` flag of the screensaver widget in order to re-draw
--- content below on re-suspend as our overlay panel region must be fully
--- re-drawn.
local function ditherScreensaverFixup()
    if not Screensaver:modeIsImage() then return end
    if G_reader_settings:readSetting("screensaver_img_background") ~= "none" then return end
    Screensaver.screensaver_widget.covers_fullscreen = false
end

local function showOrClearLockScreen(cause)
    if cause == "resume" and overlay then
        logger.dbg("ScreenLockPin: ignoring duplicate resume trigger")
        -- ignore duplicate resume (triggered by plugin:onResume), it's already
        -- been handled by overlay:onResume
        return
    end
    logger.dbg("ScreenLockPin: show lock screen (" .. cause .. ")")
    if overlay then return reuseShowOverlay() end
    logger.dbg("ScreenLockPin: create lock screen")
    screensaverUtil.freezeScreensaverAbi()
    if pluginSettings.getPreventScreenshots() then
        screenshoterUtil.freezeScreenshoterAbi()
    end
    ditherScreensaverFixup()
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
        on_unlock = function () unlockScreen("valid_pin") end,
        on_show_notes = showNotes,
    }
    UIManager:show(overlay, "flashui", overlay:getRefreshRegion())
end

return {
    showOrClearLockScreen = showOrClearLockScreen,
    unlockScreen = unlockScreen,
    isActive = function () return overlay ~= nil end,
}
