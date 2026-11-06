-- Module: F:\2025\EDrive\dev\luapack\src\shared.lua
local EventHandler = require("src.core.EventHandler")
local HotkeyManager = require("src.core.HotkeyManager")
local NotificationManager = require("src.ui.NotificationManager")

local shared_objects = {

    event_handler = EventHandler.new(),
    hotkey_manager = HotkeyManager.new(),
    notification = NotificationManager.new(),
}

return shared_objects
