local _ = require("gettext")
local Device = require("device")
local reader_order = require("ui/elements/reader_menu_order")
local fm_order = require("ui/elements/filemanager_menu_order")
local Notification = require("ui/widget/notification")

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
                callback = settingsCtrl.showChangePinDialog,
            },
        },
    },

    screenlockpin_action = {
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
    local idx = index_of(category, pos_item) + rel
    for _, name in ipairs(table.pack(...)) do
        idx = idx + 1
        table.insert(category, idx, name)
    end
end

insert_order_item(reader_order.screen, "screensaver", 0, "screenlockpin_config")
insert_order_item(fm_order.screen, "screensaver", 0, "screenlockpin_config")

insert_order_item(reader_order.exit_menu, "sleep", -1, "screenlockpin_action")
insert_order_item(fm_order.exit_menu, "sleep", -1, "screenlockpin_action")

return menus
