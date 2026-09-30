local _ = require("gettext")
local logger = require("logger")

local pluginSettings = require("plugin/settings")
local screensaverUtil = require("plugin/util/screensaverutil")
local lockscreenCtrl = require("plugin/ui/ctrl/lockscreenctrl")

--
-- Public API (for 3rd party plugins)
-- Available as `PluginShare.screen_lock_pin`.
--

local ScreenLockPinPublicApi = {}

ScreenLockPinPublicApi.isEnabled = pluginSettings.getEnabled
ScreenLockPinPublicApi.isLocked = lockscreenCtrl.isActive

function ScreenLockPinPublicApi:willLockOnBoot()
    return self:isEnabled() and pluginSettings.shouldLockOnBoot()
end

function ScreenLockPinPublicApi:willLockOnWakeup()
    return self:isEnabled() and pluginSettings.shouldLockOnBoot()
end

function ScreenLockPinPublicApi:enable(cause)
    cause = "api_" .. (cause or "unknown")
    logger.dbg("ScreenLockPin: enable via " .. cause)
    pluginSettings.setEnabled(true)
end

function ScreenLockPinPublicApi:disable(cause)
    cause = "api_" .. (cause or "unknown")
    logger.dbg("ScreenLockPin: disable via " .. cause)
    lockscreenCtrl.unlockScreen(cause)
    pluginSettings.setEnabled(false)
end

function ScreenLockPinPublicApi:disableNext(cause)
    local bool = pluginSettings.toggleDisableNext()
    if bool then
        logger.dbg("ScreenLockPin: set to disable next (via " .. cause .. ")")
    else
        logger.dbg("ScreenLockPin: revoked disable next (via " .. cause .. ")")
    end
    return bool
end

function ScreenLockPinPublicApi:toggleEnabled(cause)
    if pluginSettings.getEnabled() then
        self:disable(cause)
    else
        self:enable(cause)
    end
end

function ScreenLockPinPublicApi:lock(cause)
    cause = "api_" .. (cause or "unknown")
    logger.dbg("ScreenLockPin: lock via " .. cause)
    screensaverUtil.showWhileAwake()
    lockscreenCtrl.showOrClearLockScreen(cause)
end

function ScreenLockPinPublicApi:unlock(cause)
    cause = "api_" .. (cause or "unknown")
    logger.dbg("ScreenLockPin: unlock via " .. cause)
    lockscreenCtrl.unlockScreen(cause)
end

--

return ScreenLockPinPublicApi
