local _ = require("gettext")
local SpinWidget = require("ui/widget/spinwidget")

local pluginSettings = require("plugin/settings")

local UiSettingsDialog = SpinWidget:extend {
    title_text = _("Lock screen"),
    info_text = _("Set lock screen panel size: 0 = small, 1 = large"),

    on_save = nil,

    default_value = 0.5,
    value_min = 0,
    value_max = 1,
    value_step = 0.1,
    value_hold_step = 0.05,
    precision = "%0.2f",
    ok_always_enabled = true,
}

function UiSettingsDialog:init()
    local uiSettings = pluginSettings.getUiSettings()
    self.value = uiSettings.scale
    SpinWidget.init(self)
end

function UiSettingsDialog:callback()
    pluginSettings.setUiSettings({ scale = self.value })
    self.on_save()
end

return UiSettingsDialog
