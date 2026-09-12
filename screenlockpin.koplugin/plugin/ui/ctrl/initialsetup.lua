local _ = require("gettext")
local UIManager = require("ui/uimanager")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")

local pluginSettings = require("plugin/settings")
local PluginUpdateMgr = require("plugin/updatemanager")
local settingsCtrl = require("plugin/ui/ctrl/settingsctrl")

local is_running = false

local function actionsRequiredInfo(callback)
    UIManager:show(InfoMessage:new {
        show_icon = false,
        text = _("Initial ScreenLockPin action required. Tap to continue."),
        dismiss_callback = callback,
    })
end

local function askAutoUpdates(callback)
    UIManager:show(ConfirmBox:new{
        text = _(
            "Enable weekly update checks?\n\n" ..
            "Automatic updates will send a request to github.com to check for new releases once a week. " ..
            "This is recommended unless you use a plugin store that already covers plugin updates.\n\n" ..
            "You can change the feature at any time in the plugin settings."
        ),
        dismissable = false,
        cancel_text = _("Disable Auto-Updates"),
        cancel_callback = callback,
        ok_text = _("Enable Auto-Updates"),
        ok_callback = function()
            pluginSettings.setCheckUpdateInterval(3600 * 24 * 7)
            callback()
        end,
    })
end

local function promptInitialPin(callback)
    settingsCtrl.showChangePinDialog({ callback = function (pin_set)
        if pin_set then return callback(pin_set) end
        UIManager:show(ConfirmBox:new{
            text = _(
                "Do you want to abort the plugin setup?\n\n" ..
                "If you abort the setup, you can set the PIN later in the menu (Screen > Lock Screen) and enable the plugin afterward."
            ),
            dismissable = false,
            cancel_text = _("Abort"),
            cancel_callback = function() callback(pin_set) end,
            ok_text = _("Continue Setup"),
            ok_callback = function() promptInitialPin(callback) end,
        })
    end });
end

local function fullInitialSetupPrompts(callback)
    actionsRequiredInfo(function()
        askAutoUpdates(function ()
            promptInitialPin(function (pin_set)
                pluginSettings.writeSetupVersion()
                if not pin_set then
                    Notification:notify(_("Plugin setup incomplete."), Notification.SOURCE_DISPATCHER)
                    callback()
                    return
                end
                pluginSettings.setEnabled(true)
                UIManager:show(InfoMessage:new {
                    show_icon = false,
                    text = _("All set up.\n\nCheck the menu (Screen > Lock Screen) for further options, such as:\n · panel positioning\n · contact details for lost devices\n · and more…") ..
                        "\n\n" ..
                        _("Thank you for using this plugin.\nConsider dropping a ⭐ on github.️\n\nEnjoy!"),
                    dismiss_callback = callback,
                })
            end)
        end)
    end)
end

local function checkAndRun()
    if pluginSettings.getSetupVersion() < 1 then
        PluginUpdateMgr.instance:registerPause(function()
            if is_running then return "plugin setup running" end
            return false
        end)
        is_running = true
        fullInitialSetupPrompts(function ()
            is_running = false
            PluginUpdateMgr.instance:ping()
        end)
    end
end

return {
    checkAndRun = checkAndRun,
}
