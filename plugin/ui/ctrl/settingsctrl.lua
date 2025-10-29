local _ = require("gettext")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")

local pluginSettings = require("plugin/settings")
local ChangePinDialog = require("plugin/ui/menu/changepindialog")
local UiSettingsDialog = require("plugin/ui/menu/uisettingsdialog")

local changePinDialog
local uiSettingsDialog

local function closeChangePinDialog()
    if not changePinDialog then return end
    logger.dbg("ScreenLockPin: close change PIN dialog")
    UIManager:close(changePinDialog, "ui")
    changePinDialog = nil
end

local function showChangePinDialog()
    if changePinDialog then return end
    logger.dbg("ScreenLockPin: create change PIN dialog")
    changePinDialog = ChangePinDialog:new {
        disable_double_tap = true,
        on_submit = function(next_pin)
            pluginSettings.setPin(next_pin)
            closeChangePinDialog()
            UIManager:nextTick(function()
                Notification:notify(_("PIN changed."), Notification.SOURCE_DISPATCHER)
            end)
        end,
    }
    UIManager:show(changePinDialog)
end

local function showUiSettingsDialog()
    uiSettingsDialog = UiSettingsDialog:new {
        on_save = function()
            UIManager:close(uiSettingsDialog, "ui")
            uiSettingsDialog = nil
        end
    }
    UIManager:show(uiSettingsDialog)
end

return {
    showChangePinDialog = showChangePinDialog,
    showUiSettingsDialog = showUiSettingsDialog
}
