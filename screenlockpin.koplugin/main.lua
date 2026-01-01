local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local Dispatcher = require("dispatcher")
local PluginShare = require("pluginshare")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local EventListener = require("ui/widget/eventlistener")

local ScreenLockPinPublicApi = require("plugin/publicapi")
local pluginMenus = require("plugin/menu")
local pluginSettings = require("plugin/settings")
local PluginUpdateMgr = require("plugin/updatemanager")
local PluginKeyListener = require("plugin/keylistener")
local onBootHook = require("plugin/util/onboothook")
local screensaverUtil = require("plugin/util/screensaverutil")
local lockscreenCtrl = require("plugin/ui/ctrl/lockscreenctrl")

local ScreenLockPinPlugin = EventListener:extend {
    stopped = false
}

pluginSettings.init()

logger.dbg("ScreenLockPin: monkey-patching UIManager:run")
onBootHook.enable(function() ScreenLockPinPlugin.onBoot() end)

function ScreenLockPinPlugin:init()
    logger.dbg("ScreenLockPin: plugin init")
    Dispatcher:registerAction("screenlockpin_enable", {
        category  = "none",
        event     = "EnableLockScreen",
        title     = _("Enable lock screen"),
        device    = true,
    })
    Dispatcher:registerAction("screenlockpin_disable", {
        category  = "none",
        event     = "DisableLockScreen",
        title     = _("Disable lock screen"),
        device    = true,
    })
    Dispatcher:registerAction("screenlockpin_toggle", {
        category  = "none",
        event     = "ToggleLockScreenEnabled",
        title     = _("En/disable lock screen"),
        device    = true,
    })
    Dispatcher:registerAction("screenlockpin_lock", {
        category  = "none",
        event     = "LockScreen",
        title     = _("Lock the device"),
        device    = true,
    })
    Dispatcher:registerAction("screenlockpin_unlock", {
        category  = "none",
        event     = "UnlockScreen",
        title     = _("Unlock the device"),
        device    = true,
        separator = true,
    })
    self.ui.menu:registerToMainMenu({
        addToMainMenu = function(_, menu_items)
            logger.dbg("ScreenLockPin: adding menu items")
            for key, menu in pairs(pluginMenus) do menu_items[key] = menu end
        end
    })

    self.public_api = ScreenLockPinPublicApi
    PluginShare.screen_lock_pin = self.public_api

    PluginShare.plugin_updater_v1.registerPause(function ()
        if lockscreenCtrl.isActive() then return "ScreenLockPin:LockScreen" end
        return false
    end)

    PluginUpdateMgr.instance = PluginUpdateMgr:new {
        between_checks = pluginSettings.getCheckUpdateInterval(),
        between_remind = pluginSettings.getUpdateReminderInterval(),
    }

    self:rewireGlobalHotkeys()
end

-- KOReader dispatcher actions (registered in ScreenLockPinPlugin:init)

function ScreenLockPinPlugin:onEnableLockScreen()
    self.public_api:enable("event")
    Notification:notify(_("Lock Screen Enabled."), Notification.SOURCE_DISPATCHER)
    return true
end

function ScreenLockPinPlugin:onDisableLockScreen()
    self.public_api:disable("event")
    Notification:notify(_("Lock Screen Disabled."), Notification.SOURCE_DISPATCHER)
    return true
end

function ScreenLockPinPlugin:onToggleLockScreenEnabled()
    if pluginSettings.getEnabled() then
        self:onDisableLockScreen()
    else
        self:onEnableLockScreen()
    end
    return true
end

function ScreenLockPinPlugin:onLockScreen()
    self.public_api:lock("event")
    return true
end

function ScreenLockPinPlugin:onUnlockScreen()
    self.public_api:unlock("event")
    return true
end

-- KOReader plugin hook (on plugin disable)

function ScreenLockPinPlugin:stopPlugin()
    if self.stopped then return end
    logger.dbg("ScreenLockPin: disable plugin")
    onBootHook.disable()
    pluginSettings.destruct()
    PluginShare.screen_lock_pin = nil
    PluginUpdateMgr.instance:free()
    PluginUpdateMgr.instance = nil
    self.public_api = nil
    self.stopped = true
    return true
end

-- KOReader plugin hook (on wakeup after suspend)

function ScreenLockPinPlugin:onResume()
    if self.stopped then return end
    if not pluginSettings.getEnabled() or not pluginSettings.shouldLockOnWakeup() then
        PluginUpdateMgr.instance:ping()
        return
    end
    -- we hijacked the screensaver_delay (property of ui/screensaver.lua)
    -- any unknown values will be interpreted as "tap to exit from screensaver"
    -- this enables us to create a lock screen first before closing the
    -- screensaver. We get the responsibility to close the widget later…
    lockscreenCtrl.showOrClearLockScreen("resume")
end

-- Monkey-patched hook (registered via onBootHook)

function ScreenLockPinPlugin.onBoot()
    if not pluginSettings.getEnabled() or not pluginSettings.shouldLockOnBoot() then
        if PluginUpdateMgr.instance then PluginUpdateMgr.instance:ping() end
        return
    end
    logger.dbg("ScreenLockPin: lock on boot")
    screensaverUtil.showWhileAwake("lockonboot")
    lockscreenCtrl.showOrClearLockScreen("boot")
end

-- Hotkey register

function ScreenLockPinPlugin:rewireGlobalHotkeys()
    if not Device:hasKeyboard() then
        if PluginKeyListener.instance ~= nil then
            logger.dbg("ScreenLockPin: unregister keyboard hotkeys (keyboard disconnected)")
            UIManager:close(PluginKeyListener.instance)
            PluginKeyListener.instance = nil
        end
        return
    end
    if PluginKeyListener.instance ~= nil then return end
    PluginKeyListener.instance = PluginKeyListener:new()
    logger.dbg("ScreenLockPin: register keyboard hotkeys (keyboard detected)")
    UIManager:show(PluginKeyListener.instance)
end

ScreenLockPinPlugin.onPhysicalKeyboardConnected = ScreenLockPinPlugin.rewireGlobalHotkeys
ScreenLockPinPlugin.onPhysicalKeyboardDisconnected = ScreenLockPinPlugin.rewireGlobalHotkeys

--

return ScreenLockPinPlugin
