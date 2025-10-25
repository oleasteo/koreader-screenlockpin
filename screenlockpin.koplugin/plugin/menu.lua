local _ = require("gettext")

local pluginSettings = require("plugin/settings")
local pluginUi = require("plugin/ui/main")

return {
    sorting_hint = "screen",
    text = _("Lock screen"),
    sub_item_table = {
        {
            text = _("Lock on wakeup"),
            checked_func = pluginSettings.shouldLockOnWakeup,
            callback = pluginSettings.toggleLockOnWakeup,
        },
        {
            text = _("Lock on boot"),
            checked_func = pluginSettings.shouldLockOnBoot,
            callback = pluginSettings.toggleLockOnBoot,
            separator = true,
        },
        {
            text = _("Change PIN"),
            callback = pluginUi.showChangePinDialog,
        },
    }
}
