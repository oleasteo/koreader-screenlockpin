local logger = require("logger")
local _ = require("gettext")
local Font = require("ui/font")
local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local PinInputState = require("pininputstate")

local ScreenLockDialog = ButtonDialog:extend {
    title_align = "center",
    title_face = Font:getFace("smalltfont"),
}

function ScreenLockDialog:init()
    if not self.buttons == nil then
        -- init is called through ButtonDialog:reinit
        ButtonDialog.init(self)
        return
    end
    local ready = false
    local _valid = false
    local function on_valid_state(valid)
        if not ready then return end
        logger.dbg("ON_VALID_STATE:" .. (valid and "true" or "false"))
        _valid = valid
        local submit = self:getButtonById("submit")
        if valid then submit:enable() else submit:disable() end
    end
    local state = PinInputState:new {
        placeholder = self.placeholder,
        size_factor = self.size_factor,
        on_submit = self.on_submit,
        on_disable = self.on_disable,
        on_update = self.on_update,
        on_display_update = function(title)
            if not ready then return end
            --self:setTitle(title)
            self.title = title
            --assertNoCyclesInWidgetTree(self)
            self:reinit()
            UIManager:setDirty(self, "fast")
            -- ButtonDialog:reinit loses the submit button state :/
            on_valid_state(_valid)
        end,
        on_valid_state = on_valid_state,
    }
    self.buttons = state:makeButtons()
    self.title = state.display
    ButtonDialog.init(self)
    ready = true
end

return ScreenLockDialog
