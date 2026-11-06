-- Small internal status feedback; Sputnik's removed Notifications feature is not registered.
local N={};N.__index=N
function N.new() return setmetatable({types={INFO={},OK={},ERROR={}}},N) end
function N:show(text,kind) if msg then msg(text) else print('[Leone Menu] '..text) end end
return N
