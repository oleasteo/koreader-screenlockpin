local InputContainer = require("ui/widget/container/inputcontainer")

local publicApi = require("plugin/publicapi")

local KeyListener = InputContainer:extend {
    name = "screenlockpin:keylistener",
    is_always_active = true,
    invisible = true,
    key_events = {
        KbdLock = {
            -- universally known key combination
            { "Ctrl", "Alt", "L" },
            -- alternative, in case the above is used by system lock or similar…
            { "Alt", "Shift", "L" },
        },
    },
}

function KeyListener:onKbdLock()
    publicApi:lock("kbd_hotkey")
    return true
end

return KeyListener
