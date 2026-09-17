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

local _ = require("gettext")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local http = require("socket.http")
local util = require("util")
local JSON = require("json")
local ltn12 = require("ltn12")
local socket = require("socket")
local ffiUtil = require("ffi/util")
local Device = require("device")
local socketutil = require("socketutil")
local Archiver = require("ffi/archiver")
local Bidi = require("ui/bidi")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")
local EventListener = require("ui/widget/eventlistener")
local pluginSettings = require("plugin/settings")

--region Utilities

-- plugin meta

local function getPluginDir()
    return debug.getinfo(1, "S").source:match("@(.+%.koplugin)/")
end

local meta = dofile(getPluginDir() .. "/_meta.lua")

-- logging

local function dbg(...)
    logger.dbg("[" .. meta.name .. ":updater]", ...)
end

local function warn(...)
    logger.warn("[" .. meta.name .. ":updater]", ...)
end

local function err(...)
    logger.err("[" .. meta.name .. ":updater]", ...)
end

-- coroutines

local function runAsync(task)
    local co = coroutine.create(task)
    local function cont(...)
        local ok, stepFn = coroutine.resume(co, ...)
        if not ok then return err(stepFn) end
        if coroutine.status(co) == "dead" then return end
        stepFn(cont)
    end
    cont()
end

local function asyncStep(step, text, silent)
    local done = function() end
    if text ~= nil and not silent then
        local status_widget = InfoMessage:new { text = _(text), dismissable = false }
        UIManager:show(status_widget, "ui")
        done = function() UIManager:close(status_widget, "ui") end
    end
    dbg("step:start", text)
    coroutine.yield(function (cb) UIManager:nextTick(cb) end)
    local val = coroutine.yield(step, nil)
    done()
    dbg("step:concluded", text, val)
    return val
end

local function syncStep(step, text, silent)
    return asyncStep(function(cb) cb(step()) end, text, silent)
end

-- http

local function downloadFile(local_path, remote_url)
    dbg("Downloading update file from", remote_url, "; saving as", local_path)
    socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
    local code, headers, status = socket.skip(1, http.request {
        url      = remote_url,
        sink     = ltn12.sink.file(io.open(local_path, "w")),
    })
    socketutil:reset_timeout()
    if code ~= 200 then
        util.removeFile(local_path)
        dbg("Download failed:", status or code)
        dbg("HTTP response headers:", headers)
        local error = status or code or "network unreachable"
        return nil, error
    end
    dbg("Plugin update file download succeeded:", local_path)
    return local_path
end

local function fetchJson(request)
    local sink = {}
    request.sink = ltn12.sink.table(sink)
    socketutil:set_timeout()
    dbg("Fetching JSON", request.url)
    local code, headers, status = socket.skip(1, http.request(request))
    socketutil:reset_timeout()
    -- check network error
    if headers == nil then
        warn("Network unreachable", status or code or "unknown")
        return nil
    end
    -- check HTTP error
    if code ~= 200 then
        warn("HTTP status unexpected:", status or code or "unknown")
        dbg("HTTP response headers:", headers)
        return nil
    end
    -- quick check content JSON format
    local content = table.concat(sink)
    if content == "" or content:sub(1, 1) ~= "{" then
        warn("Expected plugin meta JSON response, got", content)
        return nil
    end
    -- parse JSON
    local ok, data = pcall(JSON.decode, content, JSON.decode.simple)
    if not ok or not data then
        warn("Failed to parse plugin meta JSON", data)
        return nil
    end
    return data
end

-- file system

local function moveFile(src, dest)
    local mv_bin = Device:isAndroid() and "/system/bin/mv" or "/bin/mv"
    return ffiUtil.execute(mv_bin, src, dest) == 0
end

local function unpackArchiveStripRoot(archive, extract_to)
    local reader = Archiver.Reader:new()
    if not reader:open(archive) then
        return false, T(_("Extracting archive failed:\n\n%1"), Bidi.filepath(archive))..string.format("\n\n(%s)", reader.err)
    end
    for node in reader:iterate() do
        local unwrapped_path = node.path and node.path:match("^[^/]*/(.*)$")
        if unwrapped_path and unwrapped_path ~= "" then
            if not reader:extractToPath(node.path, extract_to .. "/" .. unwrapped_path) then
                return false, T(_("Extracting archive failed:\n\n%1"), Bidi.filepath(archive))..string.format("\n\n(%s)", reader.err or "no error info")
            end
        end
    end
    return true
end

--endregion
--region PluginUpdater

local PluginUpdater = EventListener:extend {
    parse_plugin_info = nil,
}

--- Checks for updates.
---
--- @param args.silent nil | boolean If true, don't show any notifications during the check for updates. E.g., use this for background checks.
--- @param args.force_download nil | boolean Ignore any locally found update zip file.
--- @param args.force_update nil | boolean Update even if the version matches (intended for debugging).
--- @param args.callback nil | function Called settled state (see code below for available properties).
function PluginUpdater:checkNow(args)
    if not args then args = {} end
    local silent = args.silent or false
    local force_download = args.force_download or false
    local force_update = args.force_update or false
    local callback = args.callback or function() end

    -- state is updated during update process
    local state = {
        error = nil, -- nil | string
        local_info = meta,

        fetched_at = nil, -- nil | timestamp
        fetched_info = nil, -- nil | ReturnType<parse_plugin_info>
        update_detected = false, -- boolean
        update_forced = false, -- boolean
        
        update_dismissed_by_user_at = nil, -- nil | timestamp
        update_dismissed_by_emulator_at = nil, -- nil | timestamp
        update_triggered_at = nil, -- nil | timestamp

        plugin_dir = nil, -- nil | path
        archive_file = nil, -- nil | path
        archive_file_reuse = false, -- boolean
        extract_dir = nil, -- nil | path
        update_verified_at = nil, -- nil | timestamp
        backup_dir = nil, -- nil | path

        update_succeeded_at = nil, -- nil | timestamp
        cleanup_succeeded_at = nil, -- nil | timestamp
    }

    -- update steps

    local function checkOnline()
        if not NetworkMgr:isWifiOn() then
            state.error = "No Wi-Fi"; warn(state.error)
            if not silent then
                Notification:notify(_("Turn on Wi-Fi first."), Notification.SOURCE_DISPATCHER)
            end
            return false
        end
        if not NetworkMgr:isOnline() then
            state.error = "Not online"; warn(state.error)
            if not silent then
                Notification:notify(_("No internet connection."), Notification.SOURCE_DISPATCHER)
            end
            return false
        end
        return true
    end

    local function checkForUpdates()
        local update_url = pluginSettings.getUpdateUrl and pluginSettings.getUpdateUrl() or meta.update_url
        local json = fetchJson({ url = update_url, method = "GET" })
        if not json then
            state.error = "Fetch failed"; warn(state.error)
            if not silent then
                Notification:notify(_("Failed to fetch plugin details."), Notification.SOURCE_DISPATCHER)
            end
            return false
        end
        local fetched_info = self.parse_plugin_info(json)
        state.fetched_at = os.time()
        state.fetched_info = fetched_info
        state.update_detected = fetched_info.version ~= state.local_info.version
        if state.update_detected then
            dbg("Update available. Remote:", fetched_info.version, "Local:", state.local_info.version)
            return true
        end
        if force_update then
            state.update_forced = true
            dbg("Already on latest, but forcing update due to debug flag.", fetched_info.version)
            return true
        end
        dbg("Already on latest version. Remote:", fetched_info.version, "Local:", meta.version)
        if not silent then
            Notification:notify(T(_("You're already up to date (v%1)"), meta.version), Notification.SOURCE_DISPATCHER)
        end
        return false
    end

    local function askForUpdateAsync(callback)
        UIManager:show(InfoMessage:new {
            show_icon = false,
            text = T(_("Plugin Update available\n\n%1: %2\n[%3 → %4]\n\n%5"), meta.fullname, state.fetched_info.name, state.local_info.version, state.fetched_info.version, state.fetched_info.description),
            dismiss_callback = function()
                UIManager:show(ConfirmBox:new{
                    text = T(_("Update to %1 v%2 now?"), meta.fullname, state.fetched_info.version),
                    ok_text = _("Update"),
                    dismissable = false,
                    cancel_callback = function()
                        state.update_dismissed_by_user_at = os.time()
                        callback(false)
                    end,
                    ok_callback = function()
                        if Device.isEmulator() then
                            UIManager:show(InfoMessage:new {
                                text = _("Emulator detected.\nWe don't patch updates in emulator to spare you from nuking local code changes.\nIf you need to test the updater, use desktop KOReader instead."),
                            })
                            state.update_dismissed_by_emulator_at = os.time()
                            callback(false)
                            return
                        end
                        state.update_triggered_at = os.time()
                        callback(true)
                    end,
                })
            end
        })
    end

    local function findPluginDir()
        state.plugin_dir = getPluginDir()
        if not state.plugin_dir then
            warn("Failed to detect plugin root")
            UIManager:show(InfoMessage:new {
                text = _("Failed to detect plugin root.\nCannot perform update automatically."),
            })
            return false
        end
        return true
    end

    local function downloadUpdateFile()
        local archive_file = state.plugin_dir .. "_" .. state.fetched_info.version ..".zip"
        if lfs.attributes(archive_file) ~= nil then
            if not force_download then
                warn("Update file already present in file system. Re-using it to avoid re-download.", state.archive_file)
                Notification:notify(_("Update file found. Skipping download."), Notification.SOURCE_DISPATCHER)
                state.archive_file = archive_file
                state.archive_file_reuse = true
                return true
            end
            dbg("Update file present in file system. Removing due to force flag.", archive_file)
            local ok, err = os.remove(archive_file)
            if not ok then
                state.error = "Failed to remove old plugin update file; " .. err; warn(state.error)
                return false
            end
            dbg("Old update file removed.")
        end
        local ok, reason = downloadFile(archive_file, state.fetched_info.zip_url)
        if not ok then
            state.error = "Failed to download update file; " .. reason; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = T(_("Failed to download update file.\nPlease check connection and try again.\n\n%1"), reason),
            })
            return false
        end
        state.archive_file = archive_file
        return true
    end

    local function unpackArchive()
        local extract_dir = state.plugin_dir .. "_" .. state.fetched_info.version
        lfs.mkdir(extract_dir)
        dbg("Unpacking plugin archive " .. state.archive_file .. " to " .. extract_dir)
        local ok, err = unpackArchiveStripRoot(state.archive_file, extract_dir)
        if not ok then
            state.error = "Failed to extract update file; " .. err; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = T(_("Failed to extract update file.\n\n%1"), err),
            })
            return false
        end
        state.extract_dir = extract_dir
        return true
    end

    local function verifyUpdate()
        local meta_file = state.extract_dir .. "/_meta.lua"
        if not lfs.attributes(meta_file) then
            state.error = "Plugin validation failed (no _meta.lua file found)"; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = _("Failed to verify the patched update.\nNo _meta.lua file found.\n\nPlease check plugins/ directory and resolve situation by hand."),
            })
            return false
        end
        state.update_meta = dofile(meta_file)
        if state.update_meta.version ~= state.fetched_info.version then
            state.error = "Updated plugin version mismatch. Got " .. state.update_meta.version .. ", expected " .. state.fetched_info.version; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = _("Failed to verify the patched update (wrong version in _meta.lua).\n\nPlease check plugins/ directory and resolve situation by hand."),
            })
            return false
        end
        state.update_verified_at = os.time()
        return true
    end

    local function swapPluginDirs()
        local backup_dir = state.plugin_dir .. ".backup"
        if lfs.attributes(backup_dir) == nil then
            state.backup_dir = backup_dir
        else
            dbg("Backup dir already exists. Detecting unused suffix…")
            for num = 2, 9 do
                if not lfs.attributes(backup_dir .. "_" .. num) then
                    state.backup_dir = backup_dir .. "_" .. num
                    break
                end
            end
            if not state.backup_dir then
                state.error = "Failed to detect unused backup dir; suffix = " .. backup_dir; warn(state.error)
                UIManager:show(InfoMessage:new {
                    text = _("Failed to find available backup directory.\nCheck plugins/ to clean obsolete directories."),
                })
                return false
            end
        end
        dbg("Moving " .. state.plugin_dir .. " to " .. state.backup_dir)
        local ok = moveFile(state.plugin_dir, state.backup_dir)
        if not ok then
            state.error = "Failed to move old plugin directory"; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = _("Failed to move the old plugin directory.\nCannot perform update automatically."),
            })
            return false
        end
        dbg("Moving " .. state.extract_dir .. " to " .. state.plugin_dir)
        local ok = moveFile(state.extract_dir, state.plugin_dir)
        if not ok then
            state.error = "Failed to move new plugin directory"; warn(state.error)
            UIManager:show(InfoMessage:new {
                text = _("Failed to move the new plugin directory."),
            })
            return false
        end
        return true
    end

    local function postUpdateCleanup()
        dbg("[cleanup] Removing plugin update archive", state.archive_file)
        local error = ""
        local ok, err = os.remove(state.archive_file)
        if not ok then
            warn("Failed to remove plugin update file", err)
            if error ~= "" then error = error .. "\n\n" end
            error = error .. T(_("Failed to remove archive file:\n%1\n%2"), state.archive_file, err or "reason unknown")
        end
        dbg("[cleanup] Update extracted, purging old version", state.backup_dir)
        local ok, err = ffiUtil.purgeDir(state.backup_dir)
        if not ok then
            warn("Failed to remove old plugin dir", err)
            if error ~= "" then error = error .. "\n\n" end
            error = error .. T(_("Failed to remove old plugin directory:\n%1\n%2"), state.backup_dir, err or "reason unknown")
        end
        if error ~= "" then
            UIManager:show(InfoMessage:new {
                text = error .. "\n\n" .. _("Please check plugins/ directory and clean up by hand.")
            })
            return false
        end
        return true
    end

    -- perform update process
    runAsync(function()
        local continue = syncStep(checkOnline, "Checking online state…", silent)
        if not continue then return callback(state) end

        local continue = syncStep(checkForUpdates, "Checking for update…", silent)
        if not continue then return callback(state) end

        local continue = asyncStep(askForUpdateAsync, "Asking for update…", true)
        if not continue then return callback(state) end

        local continue = syncStep(findPluginDir, "Preparing for update…")
        if not continue then return callback(state) end

        local continue = syncStep(downloadUpdateFile, "Downloading…")
        if not continue then return callback(state) end

        local continue = syncStep(unpackArchive, "Extracting…")
        if not continue then return callback(state) end

        local continue = syncStep(verifyUpdate, "Verifying update integrity…")
        if not continue then return callback(state) end

        local continue = syncStep(swapPluginDirs, "Applying update…")
        if not continue then return callback(state) end
        state.update_succeeded_at = os.time()

        local continue = syncStep(postUpdateCleanup, "Update succeeded. Cleaning up…")
        if not continue then return callback(state) end
        state.cleanup_succeeded_at = os.time()

        UIManager:askForRestart("Plugin update succeeded. To use the new version, the device must be restarted.")
        callback(state)
    end)
end

return PluginUpdater
