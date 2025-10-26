local _ = require("gettext")
local logger = require("logger")
local Dispatcher = require("dispatcher")
local EventListener = require("ui/widget/eventlistener")

local onBootHook = require("plugin/hook/onboot")
local pluginMenu = require("plugin/menu")
local pluginSettings = require("plugin/settings")
local screensaverUtil = require("plugin/util/screensaverutil")
local pluginUi = require("plugin/ui/main")

local ScreenLockPinPlugin = EventListener:extend {}

pluginSettings.init()

logger.dbg("ScreenLockPin: monkey-patching UIManager:run")
onBootHook.enable(function() ScreenLockPinPlugin.onBoot() end)

function ScreenLockPinPlugin:init()
    logger.dbg("ScreenLockPin: plugin init")
    Dispatcher:registerAction("screenlockpin_lock", {
        category = "none",
        event    = "LockScreen",
        title    = _("Lock screen"),
        device   = true,
    })
    self.ui.menu:registerToMainMenu({
        addToMainMenu = function(_, menu_items)
            logger.dbg("ScreenLockPin: adding menu")
            menu_items.screen_lockpin_reset = pluginMenu
        end
    })
end

-- KOReader dispatcher action (registered in ScreenLockPinPlugin:init)
function ScreenLockPinPlugin:onLockScreen()
    logger.dbg("ScreenLockPin: lock via action")
    screensaverUtil.showWhileAwake("dispatcher_lockscreen")
    pluginUi.showOrClearLockScreen("dispatcher_lockscreen")
end

-- KOReader plugin hook (on plugin disable)
function ScreenLockPinPlugin.stopPlugin()
    logger.dbg("ScreenLockPin: disable plugin")
    onBootHook.disable()
    pluginSettings.purge()
    return true
end

-- KOReader plugin hook (on wakeup after suspend)
function ScreenLockPinPlugin.onResume()
    if not pluginSettings.shouldLockOnWakeup() then return end
    -- we hijacked the screensaver_delay (property of ui/screensaver.lua)
    -- any unknown values will be interpreted as "tap to exit from screensaver"
    -- this enables us to create a lock screen first before closing the
    -- screensaver. We get the responsibility to close the widget later…
    pluginUi.showOrClearLockScreen("resume")
end

-- Monkey-patched hook (registered via onBootHook)
function ScreenLockPinPlugin.onBoot()
    if not pluginSettings.shouldLockOnBoot() then return end
    logger.dbg("ScreenLockPin: lock on boot")
    screensaverUtil.showWhileAwake("lockonboot")
    pluginUi.showOrClearLockScreen("boot")
end

return ScreenLockPinPlugin
