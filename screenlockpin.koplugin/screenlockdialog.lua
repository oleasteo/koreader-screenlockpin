local _ = require("gettext")
local Font = require("ui/font")
local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local ScreenLockInput = require("screenlockinput")

-- todo inherit the ui widget instead, keep input as field
local ScreenLockDialog = ScreenLockInput:extend{ widget = nil }

function ScreenLockDialog:init()
    self.widget = ButtonDialog:new{
        title        = self.placeholder,
        title_align  = "center",
        title_face = Font:getFace("smalltfont"),
        buttons      = self:makeButtons(),
        dismissable  = true,
        show_parent = self,
    }
    UIManager:show(self.widget)
end

function ScreenLockDialog:dispose()
    UIManager:close(self.widget, "ui")
    self.widget:free()
end

function ScreenLockDialog:on_display_update(title)
    if self.widget then
        self.widget:setTitle(title)
        UIManager:setDirty(self.widget, "fast")
        -- setTitle does a re-init which loses the submit button state :/
        self:on_valid_state(self.valid)
    end
end

function ScreenLockDialog:on_valid_state(valid)
    if self.widget then
        local submit = self.widget:getButtonById("submit")
        if valid then submit:enable() else submit:disable() end
    end
end

return ScreenLockDialog
