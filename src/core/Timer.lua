-- Module: F:\2025\EDrive\dev\luapack\src\core\Timer.lua

local Timer = {}
Timer.__index = Timer

function Timer.new(interval)
    local self = setmetatable({}, Timer)
    self.interval = interval
    self.temp_interval = nil
    self.last_triggered = os.clock()
    self.paused = false
    self.paused_elapsed = 0
    return self
end

function Timer:get_active_interval()
    return self.temp_interval or self.interval[0] or 0
end

function Timer:is_ready()
    if self.paused then
        return false
    end
    local active_interval = self:get_active_interval()
    return (os.clock() - self.last_triggered) >= active_interval
end

function Timer:trigger()
    self.last_triggered = os.clock()
    self.paused = false
    self.paused_elapsed = 0
    self.temp_interval = nil
end

function Timer:time_remaining()
    local active_interval = self:get_active_interval()
    local elapsed = self.paused and self.paused_elapsed or (os.clock() - self.last_triggered)
    return math.max(0, active_interval - elapsed)
end

function Timer:set_interval(interval)
    self.interval[0] = interval
    self.temp_interval = nil
end

function Timer:set_temp_interval(interval)
    self.temp_interval = interval
    self.last_triggered = os.clock()
end

function Timer:pause()
    if not self.paused then
        self.paused_elapsed = os.clock() - self.last_triggered
        self.paused = true
    end
end

function Timer:resume()
    if self.paused then
        self.last_triggered = os.clock() - self.paused_elapsed
        self.paused = false
        self.paused_elapsed = 0
    end
end

function Timer:is_paused()
    return self.paused
end

return Timer
