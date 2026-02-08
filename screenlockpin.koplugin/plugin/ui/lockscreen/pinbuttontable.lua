local _ = require("gettext")
local ButtonTable = require("ui/widget/buttontable")

local PinButtonTable = ButtonTable:extend {
    state = nil,
    zero_sep = true,
}

function PinButtonTable:init()
    self.buttons = self.state:makeButtons()
    ButtonTable.init(self)
end

function PinButtonTable:rescale(next_width)
    self:free()
    self.dimen = nil
    self.width = next_width
    ButtonTable.init(self)
end

return PinButtonTable
