local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local ffiUtil = require("ffi/util")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local reader_order = require("ui/elements/reader_menu_order")
local fm_order = require("ui/elements/filemanager_menu_order")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")
local T = ffiUtil.template

local pluginSettings = require("plugin/settings")
local pluginApi = require("plugin/publicapi")
local PluginUpdateMgr = require("plugin/updatemanager")
local settingsCtrl = require("plugin/ui/ctrl/settingsctrl")

local function options_enabled()
    return pluginSettings.getEnabled()
end

local function change_pin_enabled()
    return pluginSettings.getEnabled() or not pluginSettings.hasPin()
end

local function getPluginDir()
    return debug.getinfo(1, "S").source:match("@(.+%.koplugin)/")
end

local meta_origin = dofile(getPluginDir() .. "/_meta.lua")

local menus = {
    screenlockpin_config = {
        sorting_hint = "screen",
        text = _("Lock screen"),
        sub_item_table = {
            {
                text = _("Enable"),
                checked_func = options_enabled,
                check_callback_updates_menu = true,
                callback = function(menu_instance)
                    if not pluginSettings.hasPin() then
                        Notification:notify(_("Set a PIN to enable"), Notification.SOURCE_DISPATCHER)
                        return
                    end
                    pluginSettings.toggleEnabled()
                    menu_instance:updateItems()
                end,
                separator = true,
            },
            {
                text = _("Lock on wakeup"),
                enabled_func = options_enabled,
                checked_func = pluginSettings.shouldLockOnWakeup,
                callback = pluginSettings.toggleLockOnWakeup,
            },
            {
                text = _("Lock on boot"),
                enabled_func = options_enabled,
                checked_func = pluginSettings.shouldLockOnBoot,
                callback = pluginSettings.toggleLockOnBoot,
                separator = true,
            },
            {
                text = _("Lock screen options"),
                enabled_func = options_enabled,
                callback = settingsCtrl.showUiSettingsDialog,
            },
            {
                text = _("Check for updates"),
                keep_menu_open = true,
                callback = function()
                    PluginUpdateMgr.instance:checkNow({ silent = false })
                end,
                separator = true,
            },
            {
                text = _("Change PIN"),
                enabled_func = change_pin_enabled,
                keep_menu_open = true,
                callback = function(menu_instance)
                    settingsCtrl.showChangePinDialog({
                        callback = function (changed)
                            if changed then
                                menu_instance:updateItems()
                                Notification:notify(_("PIN changed."), Notification.SOURCE_DISPATCHER)
                            end
                        end,
                    })
                end,
            },
            {
                text = _("About"),
                keep_menu_open = true,
                callback = function()
                    local meta = dofile(getPluginDir() .. "/_meta.lua")
                    local versions = T(_("Version: %1"), meta_origin.version)
                    if meta.version ~= meta_origin.version then
                        versions = T(_("Version running: %1"), meta_origin.version) .. "\n" .. T(_("Version on disk: %1"), meta.version)
                    end
                    UIManager:show(InfoMessage:new {
                        text = _("ScreenLockPin — Protect your KOReader with a PIN") .. "\n\n" ..
                                versions .. "\n" ..
                                T(_("Author: %1"), meta_origin.author) .. "\n\n" ..
                                _("Thank you for using this plugin.\nConsider dropping a ⭐ on github.️\n\nEnjoy!"),
                    })
                end,
            },
        },
    },

    screenlockpin_action_reboot_nolock = {
        sorting_hint = "exit_menu",
        text = _("Restart KOReader (skip lock screen)"),
        enabled_func = function()
            return options_enabled() and pluginSettings.shouldLockOnBoot()
        end,
        callback = function()
            logger.dbg("ScreenLockPin: set to disable next (via reboot menu)")
            pluginSettings.setDisableNext(true)
            UIManager:broadcastEvent(Event:new("Restart"))
        end
    },

    screenlockpin_action_lock = {
        sorting_hint = "exit_menu",
        text = _("Lock"),
        enabled_func = options_enabled,
        callback = function() pluginApi:lock("menu") end
    },
}

local function index_of(t, value)
    for i = 1, #t do if t[i] == value then return i end end
    return 0
end

local function first_index_where(t, predicate)
    for i = 1, #t do if predicate(t[i]) then return i end end
    return 0
end

local function drop_where(t, predicate)
    table.remove(t, first_index_where(t, predicate))
end

if not Device:canSuspend() then
    drop_where(menus.screenlockpin_config.sub_item_table, function(it)
        return it.text == _("Lock on wakeup")
    end)
end

local function insert_order_item(category, pos_item, rel, ...)
    if not category then return end
    local idx = index_of(category, pos_item) + rel
    for _, name in ipairs(table.pack(...)) do
        idx = idx + 1
        table.insert(category, idx, name)
    end
end

insert_order_item(reader_order.screen, "screensaver", 0, "screenlockpin_config")
insert_order_item(fm_order.screen, "screensaver", 0, "screenlockpin_config")

local function insertExitSettings(menu)
    if menu.exit_menu then
        if Device:canRestart() then
            insert_order_item(menu.exit_menu, "restart_koreader", 0, "screenlockpin_action_reboot_nolock")
        end
        insert_order_item(menu.exit_menu, "sleep", -1, "screenlockpin_action_lock")
    else
        -- on android the exit menu isn't available, as it's just an exit button
        if Device:canRestart() then
            insert_order_item(menu.main, "restart_koreader", 0, "screenlockpin_action_reboot_nolock")
        end
        insert_order_item(menu.main, "exit_menu", -1, "screenlockpin_action_lock")
    end
end

insertExitSettings(reader_order)
insertExitSettings(fm_order)

return menus
