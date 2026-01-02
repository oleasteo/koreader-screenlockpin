-- MIT License
--
-- Copyright (c) 2025 Ole Asteo
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--[[
An easy way to compare your version with upstream.

# Changelog

## [v3] - 2026-01-02
- Fixed background widget (global pings on resume and network connection)
  lifecycle. Prior to this, it caused KOReader exit / restart not to work in all
  cases (UIManager shutdown is only complete once all widgets are closed).
--]]
local UPDATER_VERSION = 3

--[[

This PluginUpdateMgr (this file) and PluginUpdater (updater.lua) are designed to
be copied into your own plugin project.

For the most part, you just need to specify at `name`, `fullname`, `update_url`,
and `version` in your _meta.lua.

We expose a public API as `PluginShare.plugin_updater_v1`.
Use it to control (all) instances of the updater from different plugins (e.g.,
ping all updaters after device unlock).

--]]

local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local PluginShare = require("pluginshare")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Notification = require("ui/widget/notification")
local EventListener = require("ui/widget/eventlistener")

-- if your plugin structure differs, this path might need adjustment
local PluginUpdater = require("plugin/updater");

--region Register Public API

local share_authority = not PluginShare.plugin_updater_v1
if share_authority then
    -- Reminder: This public API should stay backward compatible; extend, don't break. The version is the API version, __not__ the UPDATER_VERSION, btw.
    PluginShare.plugin_updater_v1 = EventListener:extend {
        _pause_predicates = {},
        --- A table of all modules; see below
        modules = {},
        --- @return nil | string The reason for being paused right now, or nil if not paused.
        isGlobalPaused = function()
            for idx, fn in ipairs(PluginShare.plugin_updater_v1._pause_predicates) do
                local val = fn()
                if val then
                    local reason = "global pause #" .. idx
                    if val ~= true then reason = reason .. " [" .. val .. "]" end
                    return reason
                end
            end
            return nil
        end,
        --- Suppress any pings on while the given predicate returns truthy. Return a reason for debugging messages.
        registerPause = function(predicate)
            table.insert(PluginShare.plugin_updater_v1._pause_predicates, predicate)
        end,
        --- Ping all background checkers to re-evaluate if an update check is
        --- desired.
        ping = function()
            local reason = PluginShare.plugin_updater_v1.isGlobalPaused()
            if reason then
                logger.dbg("[plugin_updater_v1:global]", "paused due to", reason)
                return
            end
            for _, mod in pairs(PluginShare.plugin_updater_v1.modules) do
                mod.instance:ping(true)
            end
        end,
    }

    -- Register background event listener for global pings

    local BackgroundWidget = Widget:extend {
        toast = true,
        is_always_active = true,
        invisible = true,
        stopped = false,
    }

    function BackgroundWidget:init()
        logger.dbg("Initializing background widget:", self.name)
        UIManager:show(self)
    end

    function BackgroundWidget:onClose(cause)
        if self.stopped then return end
        logger.dbg("Closing background widget ( cause =", cause, "):", self.name)
        UIManager:close(self)
        self.stopped = true
    end

    function BackgroundWidget:onExit() self:onClose("exit event") end
    function BackgroundWidget:onRestart() self:onClose("restart event") end

    BackgroundWidget:new {
        name = "plugin_updater_v1:bg_widget",
        onNetworkConnected = PluginShare.plugin_updater_v1.ping,
        onResume = PluginShare.plugin_updater_v1.ping,
    }
end

--endregion
--region Plugin Meta

local function getPluginDir()
    return debug.getinfo(1, "S").source:match("@(.+%.koplugin)/")
end

local meta = dofile(getPluginDir() .. "/_meta.lua")

local KEY_SUFFIX = "plugin_updater#" .. meta.name
local KEY_CHECKED_AT = KEY_SUFFIX .. ":checked_at"
local KEY_DISMISSED_AT = KEY_SUFFIX .. ":dismissed_at"
local KEY_DISMISSED_V = KEY_SUFFIX .. ":dismissed"

--endregion
--region Utilities

local function dbg(...)
    logger.dbg("[" .. meta.name .. ":updatemgr]", ...)
end

local function warn(...)
    logger.warn("[" .. meta.name .. ":updatemgr]", ...)
end

local function err(...)
    logger.err("[" .. meta.name .. ":updatemgr]", ...)
end

local function defaultParsePluginInfo(json)
    -- parse version
    local remote_version = json.tag_name
    if remote_version:sub(1, 1) == "v" then remote_version = remote_version:sub(2) end
    -- find zip asset
    local remote_zip_asset
    for _, asset in ipairs(json.assets or {}) do
        if asset.content_type == "application/zip" then
            remote_zip_asset = asset
            break
        end
    end
    local remote_zip_url = remote_zip_asset and remote_zip_asset.browser_download_url or json.zipball_url
    local remote_description = json.body or ""
    dbg("Parsed plugin meta successfully:", string.format("name = %s | version = %s | zip_url = %s", json.name, remote_version, remote_zip_url))
    return {
        name = json.name,
        version = remote_version,
        description = remote_description,
        zip_url = remote_zip_url,
    }
end

--endregion
--region Plugin Update Manager

local PluginUpdateMgr = EventListener:extend {
    --- The minimum duration in seconds to wait between actual checks. If nil, no checks will be performed by `ping` calls.
    between_checks = nil,
    --- The minimum duration in seconds to wait between reminders after a dismissed update. If nil, no reminders will be created on `ping` calls.
    between_remind = nil,
    max_schedule_duration = Device:isSDL() and not Device:isEmulator() and math.huge or 300,

    _updater = nil,
    _plugin_name = meta.name,
    _pause_predicates = {},
    --- idle:      idling; waiting for ping
    --- checking:  triggered updater check; waiting for callback
    --- checking_pinged: another ping was received while checking; if the current check doesn't avail, check again
    --- dismissed: an update was dismissed
    ---            — background job won't cause same version to pop up again if no reminder is enabled
    --- failed:    an update was attempted, but failed with an issue we can't recover automatically
    ---            — background job disabled
    --- freed:     free() was called, this instance is not to be used further
    ---            — no further actions possible until restart
    --- updated:   an update was performed
    ---            — no further actions possible until restart
    _state = "idle",
}

function PluginUpdateMgr:init()
    self._updater = PluginUpdater:new { parse_plugin_info = defaultParsePluginInfo }
    -- register to PluginShare
    if PluginShare.plugin_updater_v1.modules[meta.name] then
        warn("Plugin updater already found in PluginShare:", meta.name)
        return
    end
    PluginShare.plugin_updater_v1.modules[meta.name] = {
        module_version = meta.version,
        manager_version = UPDATER_VERSION,
        instance = self,
    }
    -- restore dismissed state across reboots
    if G_reader_settings:readSetting(KEY_DISMISSED_AT) ~= nil then
        self._state = "dismissed"
    end
end

--- @return boolean Whether the manager has been closed (manually, or by a successful update and pending restart)
--- @see PluginUpdateMgr.free
function PluginUpdateMgr:isClosed()
    return self._state == "freed" or self._state == "updated"
end

--- @return boolean Wehether the manager is currently waiting for a triggered update check
function PluginUpdateMgr:isChecking()
    return self._state == "checking" or self._state == "checking_pinged"
end

--- @return boolean Whether the manager could trigger further actions on ping calls
function PluginUpdateMgr:isBackgroundActive()
    if self:isClosed() then return false end
    if self._state == "failed" then return false end
    if self._state == "dismissed" then return self.between_remind ~= nil end
    return self.between_checks ~= nil
end

--- @param ignore_global_pause nil | boolean Whether to skip the global pause condition checks. Designed for performance to only be set by global ping.
--- @return nil | string Returns a string if any of the registered pause predicates is truthy.
function PluginUpdateMgr:isPaused(ignore_global_pause)
    if self:isClosed() then return "error:closed" end
    if Device.screen_saver_mode then return "static pause #1 [screensaver mode]" end
    if Device.screen_saver_lock then return "static pause #2 [screensaver lock]" end
    for idx, fn in ipairs(self._pause_predicates) do
        local val = fn()
        if val then
            local reason = "local pause #" .. idx
            if val ~= true then reason = reason .. " [" .. val .. "]" end
            return reason
        end
    end
    if not ignore_global_pause then
        return PluginShare.plugin_updater_v1.isGlobalPaused()
    end
    return nil
end

--- If you're not using a GitHub Releases compatible API endpoint, you can set
--- your own API parser to return `name`, `version`, `description`, and
--- `zip_url` from the raw JSON as returned by `_meta.lua#updater_url`.
--- @param plugin_info_parser function Converts raw JSON to an info table with the properties named above.
function PluginUpdateMgr:setParser(plugin_info_parser)
    if self:isClosed() then return nil end
    self._updater.parse_plugin_info = plugin_info_parser
end

--- Suppress any pings on while the given predicate returns truthy. Return a string to indicate the reason in debugging messages.
--- For predicates that shall apply to all updaters (e.g., lock screens), use
--- PluginShare.plugin_updater_v1.registerPause instead.
function PluginUpdateMgr:registerPause(predicate)
    if self:isClosed() then return nil end
    table.insert(self._pause_predicates, predicate)
end

--- Checks for updates, if not paused. Trigger this whenever a pause condition
--- might have changed to not pause anymore.
--- @param ignore_global_pause nil | boolean Whether to skip the global pause condition checks. Designed for performance to only be set by global ping.
function PluginUpdateMgr:ping(ignore_global_pause)
    dbg("pinged in state", self._state)
    if not self:isBackgroundActive() then return end
    if self:isChecking() then self._state = "checking_pinged" return end
    -- remaining states: idle | dismissed
    local action_key, action_interval
    if self._state == "idle" then
        action_key = KEY_CHECKED_AT
        action_interval = self.between_checks
    elseif self._state == "dismissed" then
        action_key = KEY_DISMISSED_AT
        action_interval = self.between_remind
    else
        err("unexpected state", self._state)
        return
    end
    self:_unschedule()
    if not self:_isDueOrSchedulePing(action_key, action_interval) then return end
    -- action is due
    local pause = self:isPaused(ignore_global_pause)
    if pause ~= nil then
        dbg("paused due to " .. pause)
        return
    end
    self:_check({ silent = true })
end

--- Checks for updates, ignoring paused state. This is intended for manual
--- triggers by the user (e.g., through menu item).
---
--- @param options.silent nil | boolean If true, don't show any notifications during the check for updates. E.g., use this for background checks.
--- @param options.force_download nil | boolean Ignore any locally found update zip file.
--- @param options.force_update nil | boolean Update even if the version matches (intended for debugging).
--- @param callback nil | function Called after the update procedure. Receives the result state if a check was started (see PluginUpdater:checkNow).
function PluginUpdateMgr:checkNow(options, callback)
    dbg("checkNow() called in state", self._state)
    if not options then options = {} end
    if not callback then callback = function() end end
    if self:isClosed() then
        local text = self._state == "updated" and _("Awaiting restart") or _("Updater closed")
        Notification:notify(text, Notification.SOURCE_DISPATCHER)
        callback({ closed = true, closed_reason = self._state })
        return
    end
    if self:isChecking() then
        Notification:notify(_("Already checking for updates…"), Notification.SOURCE_DISPATCHER)
        callback({ busy = true })
        return
    end
    local pause = self:isPaused()
    if pause ~= nil then warn("force check despite pause:", pause) end
    self:_check(options, callback)
end

function PluginUpdateMgr:free()
    self._updater = nil
    self._pause_predicates = {}
    if not self:isClosed() then self._state = "freed" end
end

-- wrapper function so that other pings aren't unscheduled by us
function PluginUpdateMgr:__ping()
    self:ping()
end

function PluginUpdateMgr:_check(options, callback)
    local restore_state = self._state
    dbg("starting update check (from state: " .. restore_state .. ")")
    self._state = "checking"
    self._updater:checkNow({
        silent = options.silent or false,
        force_download = options.force_download or false,
        force_update = options.force_update or false,
        callback = function(result)
            dbg("update check concluded…")
            self:_handleCheckResult(result, restore_state)
            dbg("… check concluded into state:", self._state)
            if callback then callback(result) end
        end,
    })
end

function PluginUpdateMgr:_handleCheckResult(result, prev_state)
    if not result.fetched_at then
        dbg("no info fetched; probably offline")
        if self._state == "checking_pinged" then
            UIManager:nextTick(self.ping, self)
        end
        self._state = prev_state
        return
    end
    self:_storeChecked(result.fetched_at)
    self:_unschedule()
    if result.update_dismissed_by_user_at then
        dbg("dismissed by user")
        self._state = "dismissed"
        self:_storeDismissed(result.update_dismissed_by_user_at, result.fetched_info.version)
        self:_scheduleReminder()
        return
    end
    self:_dropDismissedStore()
    if not result.update_detected and not result.update_forced then
        self._state = prev_state
        dbg("already on latest")
        return
    end
    if result.update_succeeded_at or result.update_dismissed_by_emulator_at then
        dbg("update succeeded", result.update_meta.version)
        self._state = "updated"
        -- before restart, we won't need any updater anymore
        self:free()
        return
    end
    if not result.update_triggered_at then
        -- `update_detected or update_forced` should always result in `update_triggered_at`
        err("assumed to be unreachable code", require("dump")(result))
    end
    dbg("update failed", result.error)
    -- triggered, but not succeeded => failed
    self._state = "failed"
    -- don't free() as the user may fix external issues without restarting the system
end

function PluginUpdateMgr:_storeDismissed(timestamp, version)
    dbg("store dismissed info", timestamp, version)
    G_reader_settings:saveSetting(KEY_DISMISSED_AT, timestamp)
    G_reader_settings:saveSetting(KEY_DISMISSED_V, version)
end

function PluginUpdateMgr:_dropDismissedStore()
    dbg("dropping stored dismissed info")
    G_reader_settings:delSetting(KEY_DISMISSED_AT)
    G_reader_settings:delSetting(KEY_DISMISSED_V)
end

function PluginUpdateMgr:_storeChecked(timestamp)
    dbg("store checked info", timestamp)
    G_reader_settings:saveSetting(KEY_CHECKED_AT, timestamp)
end

function PluginUpdateMgr:_scheduleReminder()
    if not self:_isDueOrSchedulePing(KEY_DISMISSED_AT, self.between_remind) then return end
    dbg("reminder is due; scheduling for next tick")
    UIManager:nextTick(self.__ping, self)
end

--- @return boolean Whether the interval type is due. If false, the function might have scheduled an internal ping timer.
function PluginUpdateMgr:_isDueOrSchedulePing(key, interval)
    if not interval or interval == 0 then
        dbg("action is disabled; no timer scheduled:", key)
        return false
    end
    local delay = self:_getRemainingDelay(key, interval)
    if delay == 0 then
        -- action is due
        return true
    end
    if delay > self.max_schedule_duration then
        dbg("no timer scheduled due to exceeding duration:", delay, "seconds")
        return false
    end
    dbg("scheduling internal ping timer:", delay, "seconds")
    UIManager:scheduleIn(delay, self.__ping, self)
    return false
end

function PluginUpdateMgr:_unschedule()
    if UIManager:unschedule(self.__ping) then
        dbg("reminder was unscheduled")
    end
end

function PluginUpdateMgr:_getRemainingDelay(key, total_delay_s)
    local last_action_timestamp = G_reader_settings:readSetting(key)
    if not last_action_timestamp then
        dbg("no timestamp was found in store", key)
        return 0
    end
    local now = os.time()
    local elapsed_s = now - last_action_timestamp
    local diff_s = total_delay_s - elapsed_s
    if diff_s >= 0 then
        dbg("remaining delay for", key, "is", diff_s, "seconds")
    else
        dbg("delay for", key, "is overdue for", -diff_s, "seconds")
    end
    return math.max(0, diff_s)
end

--endregion

return PluginUpdateMgr
