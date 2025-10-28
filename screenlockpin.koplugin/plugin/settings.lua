local logger = require("logger")

--
-- Init
--

local function migrateSettings()
    -- migrate from 2025.10
    if G_reader_settings:has("screenlockpin") then
        -- rename screenlockpin -> screenlockpin_pin
        G_reader_settings:saveSetting("screenlockpin_pin", G_reader_settings:readSetting("screenlockpin"))
        G_reader_settings:delSetting("screenlockpin")
    end
    -- migrate from 2025.10-2 and earlier
    if G_reader_settings:has("screenlockpin_returndelay") then
        -- rename screenlockpin_returndelay -> screenlockpin_restore_screensaver_delay
        G_reader_settings:saveSetting("screenlockpin_restore_screensaver_delay", G_reader_settings:readSetting("screenlockpin_returndelay"))
        G_reader_settings:delSetting("screenlockpin_returndelay")
    end
    G_reader_settings:saveSetting("screenlockpin_version", "2025.10-2")
end

local function mergeDefaultSettings()
    if G_reader_settings:hasNot("screenlockpin_onboot") then
        G_reader_settings:makeFalse("screenlockpin_onboot")
    end
    if G_reader_settings:hasNot("screenlockpin_pin") then
        G_reader_settings:saveSetting("screenlockpin_pin", "0000")
    end
    if G_reader_settings:hasNot("screenlockpin_ratelimit") then
        G_reader_settings:makeTrue("screenlockpin_ratelimit")
    end
end

local function init()
    logger.dbg("ScreenLockPin: init settings")
    migrateSettings()
    mergeDefaultSettings()
end

--
-- PIN
--

local function readPin()
    return G_reader_settings:readSetting("screenlockpin_pin")
end

local function setPin(next_pin)
    --logger.dbg("ScreenLockPin: updating PIN to " .. next_pin)
    logger.dbg("ScreenLockPin: updating PIN to [redacted]")
    G_reader_settings:saveSetting("screenlockpin_pin", next_pin)
end

--
-- Lock on wakeup
--

local function shouldLockOnWakeup()
    return G_reader_settings:readSetting("screensaver_delay") == "plugin:screenlockpin"
end

local function setLockOnWakeup(bool)
    if bool == shouldLockOnWakeup() then return false end
    if bool then
        local return_value = G_reader_settings:readSetting("screensaver_delay")
        logger.dbg("ScreenLockPin: enable lock on wakeup (restore value: " .. (return_value or "nil") .. ")")
        G_reader_settings:saveSetting("screenlockpin_restore_screensaver_delay", return_value)
        G_reader_settings:saveSetting("screensaver_delay", "plugin:screenlockpin")
    else
        local return_value = G_reader_settings:readSetting("screenlockpin_restore_screensaver_delay")
        logger.dbg("ScreenLockPin: disable lock on wakeup (restore value: " .. (return_value or "nil -> disable") .. ")")
        G_reader_settings:saveSetting("screensaver_delay", return_value or "disable")
        G_reader_settings:delSetting("screenlockpin_restore_screensaver_delay")
    end
    return true
end

local function toggleLockOnWakeup()
    return setLockOnWakeup(not shouldLockOnWakeup())
end

--
-- Lock on boot
--

local function shouldLockOnBoot()
    return G_reader_settings:isTrue("screenlockpin_onboot")
end

local function toggleLockOnBoot()
    return G_reader_settings:toggle("screenlockpin_onboot")
end

--
-- Rate Limiter
--

local function shouldRateLimit()
    return G_reader_settings:isTrue("screenlockpin_ratelimit")
end

--
-- Cleanup
--

local function purge()
    -- cause restore of foreign screensaver_delay setting
    setLockOnWakeup(false)
    -- delete all our settings
    G_reader_settings:delSetting("screenlockpin_onboot")
    G_reader_settings:delSetting("screenlockpin_pin")
    G_reader_settings:delSetting("screenlockpin_ratelimit")
    G_reader_settings:delSetting("screenlockpin_opaque")
    G_reader_settings:delSetting("screenlockpin_restore_screensaver_delay")
    G_reader_settings:delSetting("screenlockpin_version")
end

return {
    init = init,
    purge = purge,

    readPin = readPin,
    setPin = setPin,

    shouldLockOnBoot = shouldLockOnBoot,
    shouldLockOnWakeup = shouldLockOnWakeup,
    shouldRateLimit = shouldRateLimit,

    toggleLockOnBoot = toggleLockOnBoot,
    toggleLockOnWakeup = toggleLockOnWakeup,
}
