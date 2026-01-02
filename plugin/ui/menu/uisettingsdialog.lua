local _ = require("gettext")
local Device = require("device")
local ConfigDialog = require("ui/widget/configdialog")
local C_ = _.pgettext

local pluginSettings = require("plugin/settings")

local DEBUG_OPTIONS = Device:isEmulator()
--DEBUG_OPTIONS = true

local UiSettingsDialog = ConfigDialog:extend {
    is_fresh = false,
    config_options = {
        prefix = "screenlockpin",
        {
            icon = "zoom.content",
            options = {
                {
                    name = "ui_pos_y",
                    name_text = _("Vertical position"),
                    toggle = { C_("Panel position", "top"), C_("Panel position", "center"), C_("Panel position", "bottom") },
                    values = { 100, 50, 0 },
                    args = { 100, 50, 0 },
                    event = "SetPositionY",
                    more_options = true,
                    more_options_param = {
                        value_min = 0,
                        value_max = 100,
                        value_step = 2,
                        value_hold_step = 10,
                        unit = "%",
                        name = "ui_pos_y",
                        name_text = _("Set vertical panel position (0 = bottom, 100 = top)"),
                        event = "SetPositionY",
                    },
                },
                {
                    name = "ui_pos_x",
                    name_text = _("Horizontal position"),
                    toggle = { C_("Panel position", "left"), C_("Panel position", "center"), C_("Panel position", "right") },
                    values = { 0, 50, 100 },
                    args = { 0, 50, 100 },
                    event = "SetPositionX",
                    more_options = true,
                    more_options_param = {
                        value_min = 0,
                        value_max = 100,
                        value_step = 2,
                        value_hold_step = 10,
                        unit = "%",
                        name = "ui_pos_x",
                        name_text = _("Set horizontal panel position (0 = left, 100 = right)"),
                        event = "SetPositionX",
                    },
                },
                {
                    name = "ui_scale",
                    name_text = _("Panel size"),
                    toggle = { C_("Panel size", "small"), C_("Panel size", "medium"), C_("Panel size", "large") },
                    values = { 0, 40, 100 },
                    args = { 0, 40, 100 },
                    event = "SetScale",
                    more_options = true,
                    more_options_param = {
                        value_min = 0,
                        value_max = 100,
                        value_step = 2,
                        value_hold_step = 10,
                        unit = "%",
                        name = "ui_scale",
                        name_text = _("Set panel size (0 = small, 100 = large)"),
                        event = "SetScale",
                    },
                },
            },
        },
        {
            icon = "appbar.typeset",
            options = {
                {
                    name = "note_mode",
                    name_text = _("Show notes"),
                    toggle = { C_("Lock screen notes", "off"), C_("Lock screen notes", "button") },
                    args = { "disabled", "button" },
                    values = { "disabled", "button" },
                    event = "SetNoteMode",
                },
                {
                    name = "note_text",
                    name_text = _("Notes text"),
                    item_text = { _("Edit…") },
                    event = "EditNoteText",
                },
            },
        },
        {
            icon = "triangle",
            options = {
                {
                    name = "screenshots_mode",
                    name_text = _("Screenshots"),
                    toggle = { C_("Lock screen screenshots", "prevent"), C_("Lock screen screenshots", "allow") },
                    args = { "prevent", "allow" },
                    values = { "prevent", "allow" },
                    event = "SetScreenshotsMode",
                },
                {
                    name = "check_update_interval",
                    name_text = _("Check for updates"),
                    toggle = {
                        C_("Check for updates", "manual"),
                        C_("Check for updates", "daily"),
                        C_("Check for updates", "weekly"),
                        C_("Check for updates", "monthly"),
                    },
                    values = {
                        0,
                        3600 * 24,
                        3600 * 24 * 7,
                        3600 * 24 * 30,
                    },
                    args = {
                        0,
                        3600 * 24,
                        3600 * 24 * 7,
                        3600 * 24 * 30,
                    },
                    event = "SetCheckUpdateInterval",
                },
                {
                    name = "update_reminder_interval",
                    name_text = _("Dismissed update reminder"),
                    toggle = {
                        C_("Check for updates", "off"),
                        C_("Check for updates", "1 day"),
                        C_("Check for updates", "1 week"),
                        C_("Check for updates", "1 month"),
                    },
                    values = {
                        0,
                        3600 * 24,
                        3600 * 24 * 7,
                        3600 * 24 * 30,
                    },
                    args = {
                        0,
                        3600 * 24,
                        3600 * 24 * 7,
                        3600 * 24 * 30,
                    },
                    event = "SetUpdateReminderInterval",
                },
            },
        },
    },
}

local triangleOpts = UiSettingsDialog.config_options[3].options

if DEBUG_OPTIONS then
    local function insertToggle(config, label, value, pos)
        if not pos then pos = #config.toggle + 1 end
        table.insert(config.toggle, pos, label)
        table.insert(config.values, pos, value)
        table.insert(config.args, pos, value)
    end

    local update_interval = triangleOpts[2]
    local dismiss_reminder = triangleOpts[3]
    insertToggle(update_interval, "15 s", 15)
    insertToggle(dismiss_reminder, "15 s", 15)
end

if Device:isDesktop() then
    -- screenshot prevention doesn't make sense here
    table.remove(triangleOpts, 1)
end

function UiSettingsDialog:init()
    self.ui = self
    local uiSettings = pluginSettings.getUiSettings()
    local noteSettings = pluginSettings.getNoteSettings()
    local prevent_screenshots = pluginSettings.getPreventScreenshots()
    self.configurable = {
        ui_scale = uiSettings.scale,
        ui_pos_x = uiSettings.pos_x,
        ui_pos_y = 100 - uiSettings.pos_y,
        note_mode = noteSettings.mode,
        note_text = noteSettings.text,
        screenshots_mode = prevent_screenshots and "prevent" or "allow",
        check_update_interval = pluginSettings.getCheckUpdateInterval(),
        update_reminder_interval = pluginSettings.getUpdateReminderInterval(),
    }
    ConfigDialog.init(self)
end

function UiSettingsDialog:onSetPositionX(value)
    pluginSettings.setUiSetting("pos_x", value)
    self.configurable.ui_pos_x = value
    return true
end

function UiSettingsDialog:onSetPositionY(value)
    pluginSettings.setUiSetting("pos_y", 100 - value)
    self.configurable.ui_pos_y = value
    return true
end

function UiSettingsDialog:onSetScale(value)
    pluginSettings.setUiSetting("scale", value)
    self.configurable.ui_scale = value
    return true
end

function UiSettingsDialog:onSetNoteMode(value)
    pluginSettings.setNoteMode(value)
    self.configurable.note_mode = value
    return true
end

function UiSettingsDialog:onSetCheckUpdateInterval(value)
    pluginSettings.setCheckUpdateInterval(value)
    self.configurable.check_update_interval = value
    return true
end

function UiSettingsDialog:onSetUpdateReminderInterval(value)
    pluginSettings.setUpdateReminderInterval(value)
    self.configurable.update_reminder_interval = value
    return true
end

function UiSettingsDialog:onEditNoteText()
    local InputDialog = require("ui/widget/inputdialog")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen

    local current = self.configurable.note_text or ""
    self._note_input_dialog = InputDialog:new{
        title = _("Lock screen notes (emergency info / contact / etc.)"),
        input = current,
        scroll = true,
        allow_newline = true,
        text_height = Screen:scaleBySize(150),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(self._note_input_dialog)
                        self._note_input_dialog = nil
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local text = self._note_input_dialog:getInputText() or ""
                        pluginSettings.setNoteText(text)
                        self.configurable.note_text = text
                        UIManager:close(self._note_input_dialog)
                        self._note_input_dialog = nil
                    end,
                },
            },
        },
    }
    UIManager:show(self._note_input_dialog)
    self._note_input_dialog:onShowKeyboard()
    return true
end

function UiSettingsDialog:onSetScreenshotsMode(mode)
    pluginSettings.setPreventScreenshots(mode == "prevent")
    self.configurable.screenshots_mode = mode
    return true
end

return UiSettingsDialog
