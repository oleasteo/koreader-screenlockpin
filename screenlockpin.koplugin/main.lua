local _ = require("gettext")
local logger = require("logger")
local Dispatcher = require("dispatcher")
local PluginShare = require("pluginshare")
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
local initialSetupCtrl = require("plugin/ui/ctrl/initialsetup")

local ScreenLockPinPlugin = EventListener:extend { stopped = false }
local last_suspend_ts = 0

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
    Dispatcher:registerAction("screenlockpin_disable_next", {
        category  = "none",
        event     = "DisableNextLockScreen",
        title     = _("Disable lock screen once"),
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

    initialSetupCtrl.checkAndRun()
    PluginKeyListener.rewireHotkeys()
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

function ScreenLockPinPlugin:onDisableNextLockScreen()
    if self.public_api:disableNext("event") then
        Notification:notify(_("Next Lock Screen will be skipped."), Notification.SOURCE_DISPATCHER)
    else
        Notification:notify(_("Lock Screen skip revoked."), Notification.SOURCE_DISPATCHER)
    end
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

-- KOReader plugin hooks (on plugin disable)

function ScreenLockPinPlugin:stopPlugin()
    if self.stopped then return end
    logger.dbg("ScreenLockPin: disable plugin")
    onBootHook.disable()
    pluginSettings.destruct()
    PluginShare.screen_lock_pin = nil
    PluginUpdateMgr.instance:free()
    PluginUpdateMgr.instance = nil
    PluginKeyListener.dropHotkeys()
    self.public_api = nil
    self.stopped = true
    return true
end

function ScreenLockPinPlugin:deletePluginSettings()
    logger.dbg("ScreenLockPin: deleting plugin settings")
    pluginSettings.dropAll()
    PluginUpdateMgr.dropPluginCache()
end

-- KOReader plugin hooks

function ScreenLockPinPlugin:onSuspend()
    if not lockscreenCtrl.isActive() then
        last_suspend_ts = os.time()
        logger.dbg("ScreenLockPin: suspend timestamp", last_suspend_ts)
    end
end

local function isShortSuspend()
    local threshold = pluginSettings.getShortSuspendThreshold()
    if threshold == 0 then return false end
    local elapsed = os.difftime(os.time(), last_suspend_ts)
    if elapsed >= 0 and elapsed <= threshold then
        logger.dbg("ScreenLockPin: detected short suspend [" .. elapsed .. " seconds] below threshold (" .. threshold .. " seconds)")
        return true
    end
    return false
end

function ScreenLockPinPlugin:onResume()
    if self.stopped then return end
    if not pluginSettings.shouldLockOnWakeup() then
        PluginUpdateMgr.instance:ping()
        return
    end
    -- make sure to use up disable next with higher priority than other disables
    local tmp_disabled = pluginSettings.useDisableNext()
    if not tmp_disabled and not pluginSettings.getEnabled() then
        PluginUpdateMgr.instance:ping()
        return
    end
    if tmp_disabled or isShortSuspend() then
        lockscreenCtrl.skipLock()
        -- no update manager ping as those temporary disables suggest the user doesn't want any
        -- disruptions
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
    if not pluginSettings.shouldLockOnBoot() then
        if PluginUpdateMgr.instance then PluginUpdateMgr.instance:ping() end
        return
    end
    -- make sure to use up disable next with higher priority than other disables
    local tmp_disabled = pluginSettings.useDisableNext()
    if not tmp_disabled and not pluginSettings.getEnabled() then
        if PluginUpdateMgr.instance then PluginUpdateMgr.instance:ping() end
        return
    end
    if tmp_disabled then
        -- no update manager ping as those temporary disables suggest the user doesn't want any
        -- disruptions
        return
    end
    logger.dbg("ScreenLockPin: lock on boot")
    screensaverUtil.showWhileAwake("lockonboot")
    lockscreenCtrl.showOrClearLockScreen("boot")
end

-- Wire keyboard related hooks

ScreenLockPinPlugin.onPhysicalKeyboardConnected = PluginKeyListener.rewireHotkeys
ScreenLockPinPlugin.onPhysicalKeyboardDisconnected = PluginKeyListener.rewireHotkeys

--

return ScreenLockPinPlugin
