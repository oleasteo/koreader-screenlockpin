local logger = require("logger")
local Device = require("device")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")

local uiManagerUtil = require("plugin/util/uimanagerutil")

local function noop() end

local _setup
local _show
local _close

local function freezeScreensaverAbi()
    if Screensaver.setup == noop then return end
    logger.dbg("ScreenLockPin: monkey-patching Screensaver:setup,show,close with noop")
    _setup = Screensaver.setup
    _show = Screensaver.show
    _close = Screensaver.close
    Screensaver.setup = noop
    Screensaver.show = noop
    Screensaver.close = noop
end

local function unfreezeScreensaverAbi()
    if Screensaver.setup ~= noop then return end
    logger.dbg("ScreenLockPin: restoring original Screensaver:setup,show,close")
    Screensaver.setup = _setup
    Screensaver.show = _show
    Screensaver.close = _close
    _setup = nil
    _show = nil
    _close = nil
end

local function showWhileAwake(event, message)
    if Screensaver.setup == noop then return end
    Screensaver:setup(event, message)
    Screensaver:show()
    -- Device has two properties that determine if a power key press emits
    -- `Suspend` or `Resume`: screen_saver_mode and screen_saver_lock.
    --
    -- `mode && !lock` => Resume  ("suspended screen saver")
    -- `mode && lock`  => Suspend ("awake screen saver, but still locked")
    -- `!mode`         => Suspend ("awake and unlocked")
    --
    -- Since Screensaver:show() sets `mode = true`, we need to add `lock = true`
    -- in this case, since we keep the device awake.
    Device.screen_saver_lock = true
end

local function totalCleanup()
    uiManagerUtil.closeWidgetsOfClass(ScreenSaverWidget)
    Screensaver:cleanup()
end

return {
    freezeScreensaverAbi = freezeScreensaverAbi,
    unfreezeScreensaverAbi = unfreezeScreensaverAbi,

    showWhileAwake = showWhileAwake,
    totalCleanup = totalCleanup,
}
