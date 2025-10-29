local UIManager = require("ui/uimanager")

--
-- This patch allows us to hook into the "device boot" with very early startup
-- code execution.
--

local _run

local function enable(callback)
    if _run then return end
    _run = UIManager.run
    local function uiRunInjected(self)
        callback()
        return _run(self)
    end
    UIManager.run = uiRunInjected
end

local function disable()
    if not _run then return end
    UIManager.run = _run
    _run = nil
end

return {
    enable = enable,
    disable = disable,
}
