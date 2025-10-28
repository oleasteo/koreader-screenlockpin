local _ = require("gettext")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")

local pluginSettings = require("plugin/settings")
local ChangePinDialog = require("plugin/ui/menu/changepindialog")

local dialog

local function closeChangePinDialog()
    if not dialog then return end
    logger.dbg("ScreenLockPin: close change PIN dialog")
    UIManager:close(dialog, "ui")
    dialog = nil
end

local function showChangePinDialog()
    if dialog then return end
    logger.dbg("ScreenLockPin: create change PIN dialog")
    dialog = ChangePinDialog:new {
        -- UIManager performance tweak
        disable_double_tap = true,
        -- ChangePinDialog
        on_submit = function(next_pin)
            pluginSettings.setPin(next_pin)
            closeChangePinDialog()
            UIManager:nextTick(function()
                Notification:notify(_("PIN changed."), Notification.SOURCE_DISPATCHER)
            end)
        end,
    }
    UIManager:show(dialog)
end

return {
    showChangePinDialog = showChangePinDialog,
}
