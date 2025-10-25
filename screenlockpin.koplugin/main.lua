local _ = require("gettext")
local logger = require("logger")
local Dispatcher = require("dispatcher")
local Screensaver = require("ui/screensaver")
local EventListener = require("ui/widget/eventlistener")

local onBootHook = require("plugin/hook/onboot")
local pluginMenu = require("plugin/menu")
local pluginSettings = require("plugin/settings")
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
    pluginUi.showOrClearLockScreen()
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
    logger.dbg("ScreenLockPin: lock on resume")
    -- we hijack the screensaver_delay (property of ui/screensaver.lua)
    -- any unknown values will be interpreted as "tap to exit from screensaver"
    -- this enables us to create a lock screen first before closing the
    -- screensaver. But we get the responsibility to close the widget when done.
    pluginUi.showOrClearLockScreen()
    Screensaver:close_widget()
end

-- Monkey-patched hook (registered via onBootHook)
function ScreenLockPinPlugin.onBoot()
    if not pluginSettings.shouldLockOnBoot() then return end
    logger.dbg("ScreenLockPin: lock on boot")
    pluginUi.showOrClearLockScreen()
end

return ScreenLockPinPlugin
