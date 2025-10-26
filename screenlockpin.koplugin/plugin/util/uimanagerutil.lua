local logger = require("logger")
local UIManager = require("ui/uimanager")

local function noop() end

local function pullModalToFront(widget, refreshtype, trigger_events)
    local first = true
    local found = false
    for i = #UIManager._window_stack, 0, -1 do
        local window = UIManager._window_stack[i]
        if window.widget == widget then
            if first then return end
            found = true
            break
        end
        if not window.widget.toast then first = false end
    end
    if not found then return end
    logger.dbg("ScreenLockPin: pulling widget to front: ", widget.name or widget.id or tostring(widget))
    -- at least one other widget found in front, so pull to top
    local _handleEvent = widget.handleEvent
    if not trigger_events then widget.handleEvent = noop end
    UIManager:close(widget, nil)
    UIManager:show(widget, refreshtype)
    if not trigger_events then widget.handleEvent = _handleEvent end
end

local function closeWidgetsOfClass(Class, refreshtype)
    logger.dbg("ScreenLockPin: closing all widgets of class: ", Class.name or Class.id or tostring(Class))
    for i = #UIManager._window_stack, 0, -1 do
        local window = UIManager._window_stack[i]
        if window then
            local widget = window.widget
            if getmetatable(widget).__index == Class then
                UIManager:close(widget, refreshtype)
            end
        end
    end
end

return {
    pullModalToFront = pullModalToFront,
    closeWidgetsOfClass = closeWidgetsOfClass,
}
