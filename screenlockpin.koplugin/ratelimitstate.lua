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

local RateLimitState = EventListener:extend {
    on_lock = nil,
    on_unlock = nil,

    attempts_by_length = nil,
    lock_counter = 0,
    last_lock_time = nil,
    unlock_time = nil,
}

function RateLimitState:init()
    self.attempts_by_length = {}
end

function RateLimitState:isLocked()
    if not self.unlock_time then return false end
    if time.now() - self.unlock_time >= 0 then
        self:unlock()
        return false
    end
    return true
end

function RateLimitState:remainingInS()
    return math.max(0, math.ceil((self.unlock_time - time.now()) / TIME_S))
end

function RateLimitState:unlock()
    logger.dbg("PinLockState: unlocking")
    self.unlock_time = nil
    if self.on_unlock then self.on_unlock() end
end

function RateLimitState:registerFailure(len)
    -- reset lock counter if it has been quiet long enough
    if self.last_lock_time and (time.now() - self.last_lock_time) >= LOCK_COUNTER_RESET_AFTER then
        logger.dbg("PinLockState: reset counters due to long time since last failure")
        self:reset()
    end
    -- len: length of the attempted PIN
    self.attempts_by_length[len] = (self.attempts_by_length[len] or 0) + 1
    logger.dbg(string.format("PinLockState: failure on %d×len(%d)", self.attempts_by_length[len], len))
    if self.attempts_by_length[len] >= FAIL_TRIGGER_PER_LENGTH then self:lock() end
end

function RateLimitState:lock()
    self.lock_counter = self.lock_counter + 1
    self.last_lock_time = time.now()
    local idx = math.min(#LOCK_DURATIONS, self.lock_counter)
    local duration = time.s(LOCK_DURATIONS[idx])
    self.unlock_time = self.last_lock_time + duration
    UIManager:schedule(self.unlock_time, function() self:unlock() end)
    logger.dbg(string.format("PinLockState: locked for %ds (counter=%d)", duration / TIME_S, self.lock_counter))
    -- reset attempts after each lock
    self.attempts_by_length = {}
    if self.on_lock then self.on_lock() end
end

function RateLimitState:reset()
    self.attempts_by_length = {}
    self.lock_counter = 0
    self.last_lock_time = nil
end

return RateLimitState
