local _ = require("gettext")
local logger = require("logger")
local UIManager = require("ui/uimanager")

local pluginSettings = require("plugin/settings")
local ChangePinDialog = require("plugin/ui/menu/changepindialog")
local UiSettingsDialog = require("plugin/ui/menu/uisettingsdialog")

local changePinDialog
local uiSettingsDialog

local function closeChangePinDialog()
    if not changePinDialog then return end
    logger.dbg("ScreenLockPin: close change PIN dialog")
    UIManager:close(changePinDialog, "flashui")
    changePinDialog = nil
end

local function showChangePinDialog(opts)
    if changePinDialog then return end
    logger.dbg("ScreenLockPin: create change PIN dialog")
    changePinDialog = ChangePinDialog:new {
        disable_double_tap = true,
        on_submit = function(next_pin)
            pluginSettings.setPin(next_pin)
            closeChangePinDialog()
            opts.callback(true)
        end,
        on_close = function()
            closeChangePinDialog()
            opts.callback(false)
        end,
    }
    UIManager:show(changePinDialog)
end

local function showUiSettingsDialog()
    uiSettingsDialog = UiSettingsDialog:new {
        close_callback = function()
            UIManager:close(uiSettingsDialog, "flashui")
            uiSettingsDialog = nil
        end,
    }
    UIManager:show(uiSettingsDialog)
end

return {
    showChangePinDialog = showChangePinDialog,
    showUiSettingsDialog = showUiSettingsDialog
}
