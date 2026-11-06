-- Module: F:\2025\EDrive\dev\luapack\src\core\EventHandler.lua

local EventHandler = {}
EventHandler.__index = EventHandler

function EventHandler.new()
    local self = setmetatable({}, EventHandler)
    self.handlers = {}
    return self
end

function EventHandler:register(event_name, condition, action)
    self.handlers[event_name] = self.handlers[event_name] or {}

    table.insert(self.handlers[event_name], {
        condition = condition,
        action = action
    })
end

function EventHandler:process(event_name, ...)
    local handlers = self.handlers[event_name]
    if not handlers then return ... end

    local should_return_false = false
    local last_result = nil

    for _, handler in ipairs(handlers) do
        local ok_cond, match = pcall(handler.condition, ...)
        if not ok_cond then
            print(string.format("Error in condition for '%s': %s", event_name, match))
        elseif match then
            local ok_action, result
            if type(match) == "table" then
                ok_action, result = pcall(handler.action, table.unpack(match))
            else
                ok_action, result = pcall(handler.action, ...)
            end

            if not ok_action then
                print(string.format("Error in action for '%s': %s", event_name, result))
            elseif result == false then
                should_return_false = true
            elseif type(result) == "table" then
                if #result == select('#', ...) then
                    last_result = result
                else
                    print(string.format("Warning: Action for '%s' returned %d parameters, expected %d",
                        event_name, #result, select('#', ...)))
                end
            end
        end
    end

    if should_return_false then
        return false
    elseif last_result then
        return last_result
    end

    return true
end

return EventHandler
