local time = require("ui/time")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local EventListener = require("ui/widget/eventlistener")

local TIME_S = time.s(1)
local LOCK_DURATIONS = {10, 30, 60}
local LOCK_COUNTER_RESET_AFTER = time.s(300)
local FAIL_TRIGGER_PER_LENGTH = 4

-- debugging values
--LOCK_DURATIONS = {2, 4, 6}
--LOCK_COUNTER_RESET_AFTER = time.s(15)
--FAIL_TRIGGER_PER_LENGTH = 2

local Throttle = EventListener:extend {
    on_pause = nil,
    on_resume = nil,

    attempts_by_length = nil,
    lock_counter = 0,
    paused_at = nil,
    resume_at = nil,
}

function Throttle:init()
    self.attempts_by_length = {}
end

function Throttle:pushAt(len)
    -- reset lock counter if it has been quiet long enough
    if self.paused_at and (time.now() - self.paused_at) >= LOCK_COUNTER_RESET_AFTER then
        logger.dbg("ScreenLockPin: reset throttle due to long time since last failure")
        self:reset()
    end
    -- len: length of the attempted PIN
    self.attempts_by_length[len] = (self.attempts_by_length[len] or 0) + 1
    logger.dbg(string.format("ScreenLockPin: throttle failures on %d digits: %d", len, self.attempts_by_length[len]))
    if self.attempts_by_length[len] >= FAIL_TRIGGER_PER_LENGTH then self:pause() end
end

function Throttle:pause()
    self.lock_counter = self.lock_counter + 1
    self.paused_at = time.now()
    local idx = math.min(#LOCK_DURATIONS, self.lock_counter)
    local duration = time.s(LOCK_DURATIONS[idx])
    self.resume_at = self.paused_at + duration
    UIManager:schedule(self.resume_at, function() self:resume() end)
    logger.dbg(string.format("ScreenLockPin: throttled for %d seconds (throttle no. %d)", duration / TIME_S, self.lock_counter))
    -- reset attempts after each lock
    self.attempts_by_length = {}
    if self.on_pause then self.on_pause() end
end

function Throttle:resume()
    logger.dbg("ScreenLockPin: throttle concluded")
    self.resume_at = nil
    if self.on_resume then self.on_resume() end
end

function Throttle:isPaused()
    if not self.resume_at then return false end
    if time.now() - self.resume_at >= 0 then
        self:resume()
        return false
    end
    return true
end

function Throttle:remainingSeconds()
    return math.max(0, math.ceil((self.resume_at - time.now()) / TIME_S))
end

function Throttle:reset()
    self.attempts_by_length = {}
    self.lock_counter = 0
    self.paused_at = nil
end

return Throttle
