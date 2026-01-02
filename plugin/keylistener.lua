local Device = require("device")
local InputContainer = require("ui/widget/container/inputcontainer")

local publicApi = require("plugin/publicapi")
local BackgroundWidget = require("plugin/ui/backgroundwidget")

local KeyListener = InputContainer:extend {
    name = "screenlockpin:keylistener",

    key_events = {
        KbdLock = {
            -- universally known key combination
            { "Ctrl", "Alt", "L" },
            -- alternative, in case the above is used by system lock or similar…
            { "Alt", "Shift", "L" },
        },
    },
    -- extend BackgroundWidget
    toast = true,
    is_always_active = true,
    invisible = true,
    stopped = false,
}

function KeyListener:init()
    -- extend BackgroundWidget
    BackgroundWidget.init(self)
end

-- extend BackgroundWidget
KeyListener.onClose = BackgroundWidget.onClose
KeyListener.onExit = BackgroundWidget.onExit
KeyListener.onRestart = BackgroundWidget.onRestart

function KeyListener:onKbdLock()
    publicApi:lock("kbd_hotkey")
    return true
end

local key_listener_instance

local function dropHotkeys()
    if key_listener_instance == nil then return end
    key_listener_instance:onClose("keyboard disconnect")
    key_listener_instance = nil
end

local function ensureHotkeys()
    if key_listener_instance ~= nil then return end
    key_listener_instance = KeyListener:new()
end

local function rewireHotkeys()
    if Device:hasKeyboard() then ensureHotkeys() else dropHotkeys() end
end

return {
    rewireHotkeys = rewireHotkeys,
    dropHotkeys = dropHotkeys,
}
