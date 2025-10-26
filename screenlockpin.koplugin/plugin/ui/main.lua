local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local ChangePinDialog = require("plugin/ui/changepindialog")
local LockScreenFrame = require("plugin/ui/lockscreenframe")

local overlay
local dialog

local function onSetRotationMode(_, mode)
    if not overlay then return end
    local old_mode = Screen:getRotationMode()
    logger.dbg("ScreenLockPin: update rotation from " .. old_mode .. " to " .. mode)
    if mode ~= nil and mode ~= old_mode then
        Screen:setRotationMode(mode)
        overlay:relayout()
    end
end

local function closeLockScreen()
    if not overlay then return end
    logger.dbg("ScreenLockPin: close lock screen")
    UIManager:close(overlay, "full")
    overlay = nil
end

local function showOrClearLockScreen()
    if overlay then return overlay:clearInput() end
    logger.dbg("ScreenLockPin: create lock screen")
    overlay = LockScreenFrame:new {
        -- UIManager performance tweaks
        covers_fullscreen = true,
        disable_double_tap = true,
        -- UIManager hook (called on ui root elements): handle rotation if not locked to orientation
        onSetRotationMode,
        -- UIManager hook (called on ui root elements)
        onScreenResize = function () overlay:relayout() end,
        -- LockScreenFrame
        on_unlock = closeLockScreen
    }
    UIManager:show(overlay)
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
