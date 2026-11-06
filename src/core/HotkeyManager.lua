-- Module: F:\2025\EDrive\dev\luapack\src\core\HotkeyManager.lua

local bit = require("bit")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local vk = require("vkeys")
local wm = require("windows.message")

local HotkeyManager = {}
HotkeyManager.__index = HotkeyManager

HotkeyManager.MAX_COMBO = 2

HotkeyManager.TEXT = {
    WAIT = "Press a key / hold two keys...",
    NONE = "None"
}

local MOUSE_BUTTONS={{1,0x201,0x202,0},{2,0x204,0x205,0},{4,0x207,0x208,0},
        {5,0x20B,0x20C,65536},{6,0x20B,0x20C,131072}}

local function _get_modifier_key(key, lparam)
    if key == vk.VK_MENU then
        return bit.band(lparam, 0x01000000) ~= 0 and vk.VK_RMENU or vk.VK_LMENU
    elseif key == vk.VK_SHIFT then
        local scan = bit.band(bit.rshift(lparam, 16), 0xFF)
        return scan == 0x36 and vk.VK_RSHIFT or vk.VK_LSHIFT
    elseif key == vk.VK_CONTROL then
        return bit.band(lparam, 0x01000000) ~= 0 and vk.VK_RCONTROL or vk.VK_LCONTROL
    end
    return key
end

local function _keys_to_string(keys)
    local t = {}
    for i, k in ipairs(keys) do
        t[i] = vk.id_to_name(k) or tostring(k)
    end
    return table.concat(t, " + ")
end

local function _is_key_combo_taken(registered, keys, except)
    for name, data in pairs(registered) do
        if name ~= except and #data.keys > 0 and #data.keys == #keys then
            local match = true

            for i, k in ipairs(keys) do
                local found=false
                for _,other in ipairs(data.keys) do if k==other then found=true;break end end
                if not found then
                    match = false
                    break
                end
            end

            if match then return true end
        end
    end
    return false
end

local function _cancel_edit(self)
    if self.edit_target then
        self.registered[self.edit_target].keys = self.backup_keys
    end
    self.edit_mode = false
    self.edit_target = nil
    self.edit_recorded = {}
    self.pressed = {}
end

local function _confirm_edit(self)
    if self.edit_target then
        if #self.edit_recorded > 0 and _is_key_combo_taken(self.registered, self.edit_recorded, self.edit_target) then
            _cancel_edit(self)
            return
        end

        local hot = self.registered[self.edit_target]
        hot.keys = self.edit_recorded
        hot.new_keys = self.edit_recorded
    end

    self.edit_mode = false
    self.edit_target = nil
    self.edit_recorded = {}
    self.pressed = {}
end

local function _handle_edit_key_down(self,key)
    if key==vk.VK_ESCAPE then _cancel_edit(self);self.ui_release=true;return end
    if key==vk.VK_BACK then self.edit_recorded={};_confirm_edit(self);self.ui_release=true;return end
    -- Capture only keys that overlap physically; release commits immediately.
    if #self.edit_recorded==0 then
        for _,mod in ipairs({vk.VK_LCONTROL,vk.VK_RCONTROL,vk.VK_LSHIFT,vk.VK_RSHIFT,vk.VK_LMENU,vk.VK_RMENU}) do
            if mod~=key and self.pressed[mod] and #self.edit_recorded<self.MAX_COMBO-1 then
                self.edit_recorded[#self.edit_recorded+1]=mod
            end
        end
    end
    for _,k in ipairs(self.edit_recorded) do if k==key then return end end
    if #self.edit_recorded<self.MAX_COMBO then self.edit_recorded[#self.edit_recorded+1]=key end
end

local function _try_execute_hotkeys(self)
    if isGameWindowForeground and not isGameWindowForeground()then return end
    if sampGetGamestate and sampGetGamestate()~=3 then return end
    if sampIsLocalPlayerSpawned and not sampIsLocalPlayerSpawned()then return end
    local list = {}

    for name, data in pairs(self.registered) do
        if name ~= self.edit_target and #data.keys > 0 and not is_cursor_active() and not sampIsChatInputActive() and not sampIsDialogActive() and not require("src.ui.MainWindow"):is_open() then
            table.insert(list, { name = name, keys = data.keys, cb = data.cb })
        end
    end

    table.sort(list, function(a, b) return #a.keys > #b.keys end)

    for _, hotkey in ipairs(list) do
        if self:is_combo_active(hotkey.keys) and type(hotkey.cb) == "function" then
            if not self.triggered[hotkey.name] then
                self.triggered[hotkey.name] = true
                local ok,err=pcall(hotkey.cb,hotkey.name)
                if not ok then print(string.format("Error in hotkey '%s': %s",hotkey.name,tostring(err)))end
                break
            end
        else
            self.triggered[hotkey.name] = nil
        end
    end
end

local function _on_window_message(self, msg, wparam, lparam)
    if msg == wm.WM_SETFOCUS or msg == wm.WM_KILLFOCUS then
        self.pressed = {}
        self.triggered = {}
        self.ui_release=true
        self.mouse_needs_sync=true

        self.edit_mode = false
        self.edit_target = nil
        self.edit_recorded = {}

        return
    end

    local mouse_down = {[0x201]=1,[0x204]=2,[0x207]=4}
    local mouse_up = {[0x202]=1,[0x205]=2,[0x208]=4}
    local mouse_key = mouse_down[msg] or mouse_up[msg]
    if msg==0x20B or msg==0x20C then mouse_key=bit.rshift(wparam,16)==1 and 5 or 6 end
    local is_down = (msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN or mouse_down[msg]~=nil or msg==0x20B)
    local is_up = (msg == wm.WM_KEYUP or msg == wm.WM_SYSKEYUP or mouse_up[msg]~=nil or msg==0x20C)
    if not (is_down or is_up) then return end

    local key = mouse_key or _get_modifier_key(wparam, lparam)

    if is_down then
        if not self.pressed[key] then
            self.pressed[key] = true
            if self.edit_mode then
                _handle_edit_key_down(self, key)
                consumeWindowMessage(true, true)
            else
                _try_execute_hotkeys(self)
            end
        end
    else
        local recording=self.edit_mode
        if recording then
            for _,k in ipairs(self.edit_recorded) do
                if k==key then _confirm_edit(self);self.ui_release=true;break end
            end
            consumeWindowMessage(true,true)
        end
        self.pressed[key] = nil
        for name, data in pairs(self.registered) do
            for _, k in ipairs(data.keys) do
                if k == key then
                    self.triggered[name] = nil
                    break
                end
            end
        end
    end
end

function HotkeyManager.new()
    local self = setmetatable({}, HotkeyManager)
    self.registered = {}
    self.pressed = {}
    self.edit_mode = false
    self.edit_target = nil
    self.edit_recorded = {}
    self.backup_keys = {}
    self.triggered = {}
    self.mouse_needs_sync=true

    addEventHandler("onWindowMessage", function(msg, wparam, lparam)
        _on_window_message(self, msg, wparam, lparam)
    end)

    return self
end

-- GTA can consume mouse input without delivering a matching WM button event.
-- Feed physical transitions through the same path; existing WM events deduplicate.
function HotkeyManager:update()
    if not isKeyDown or self.edit_mode then return end
    if isGameWindowForeground and not isGameWindowForeground() then
        self.mouse_needs_sync=true;self.pressed={};self.triggered={};return
    end

    if self.mouse_needs_sync then
        self.triggered={}
        for _,button in ipairs(MOUSE_BUTTONS)do self.pressed[button[1]]=isKeyDown(button[1])or nil end
        self.mouse_needs_sync=false
        return
    end
    for _,button in ipairs(MOUSE_BUTTONS)do
        local down=isKeyDown(button[1])
        if down and not self.pressed[button[1]] then _on_window_message(self,button[2],button[4],0)
        elseif not down and self.pressed[button[1]] then _on_window_message(self,button[3],button[4],0)end
    end
end

function HotkeyManager:register(name, keys, cb)
    if self.registered[name] then return false end

    if keys and #keys > 0 and _is_key_combo_taken(self.registered, keys) then
        return false
    end

    self.registered[name] = { keys = keys or {}, cb = cb }
    return true
end

function HotkeyManager:unregister(name)
    if not self.registered[name] then return false end

    self.registered[name] = nil
    return true
end

function HotkeyManager:update_keys(name, keys)
    if not self.registered[name] then return false end

    if keys and #keys > 0 and _is_key_combo_taken(self.registered, keys, name) then
        return false
    end

    self.registered[name].keys = keys
    return true
end

function HotkeyManager:update_callback(name, cb)
    if not self.registered[name] then return false end

    self.registered[name].cb = cb
    return true
end

function HotkeyManager:is_combo_active(combo)
    if #combo == 0 then
        return false
    end

    for _, k in ipairs(combo) do
        if not self.pressed[k] then
            return false
        end
    end

    return true
end

function HotkeyManager:start_editing(name)
    local hotkey = self.registered[name]
    if not hotkey then
        return false
    end

    self.edit_mode = true
    self.edit_target = name
    self.edit_recorded = {}
    self.backup_keys = {}
    self.pressed = {}
    if isKeyDown then
        for _,mod in ipairs({vk.VK_LCONTROL,vk.VK_RCONTROL,vk.VK_LSHIFT,vk.VK_RSHIFT,vk.VK_LMENU,vk.VK_RMENU}) do
            if isKeyDown(mod) then self.pressed[mod]=true end
        end
    end

    for i, k in ipairs(hotkey.keys) do
        self.backup_keys[i] = k
    end

    return true
end

function HotkeyManager:get_edit_status()
    if not self.edit_mode then return nil end

    if #self.edit_recorded > 0 then
        return _keys_to_string(self.edit_recorded) .. " (release to set)"
    end

    return self.TEXT.WAIT
end

function HotkeyManager:get_all()
    local t = {}

    for name, data in pairs(self.registered) do
        t[name] = {
            keys = data.keys,
            text = (#data.keys > 0) and _keys_to_string(data.keys) or "None"
        }
    end

    return t
end

function HotkeyManager:flush_ui_input()
    if not self.ui_release then return end
    self.ui_release=false
    if imgui.ClearActiveID then imgui.ClearActiveID() end
    imgui.GetIO():ClearInputKeys()
end

function HotkeyManager:draw_key_editor(name, size)
    local hotkey = self.registered[name]
    if not hotkey then
        imgui.AnimButton("Missing bind: " .. name, size)
        return
    end

    local text
    if self.edit_target == name then
        text = self:get_edit_status()
    else
        text = (#hotkey.keys > 0) and _keys_to_string(hotkey.keys) or self.TEXT.NONE
    end

    if imgui.AnimButton(fa("KEYBOARD") .. " " .. text .. "##" .. name, size) then
        self:start_editing(name)
    end

    if hotkey.new_keys then
        local nk = hotkey.new_keys
        hotkey.new_keys = nil
        return nk
    end
end

return HotkeyManager
