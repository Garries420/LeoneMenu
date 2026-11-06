-- Skip an actually selected parachute using the player's existing weapons.
local bit = require('bit')
local keys = require('game.keys').player
local MainWindow = require('src.ui.MainWindow')
local P = {}
P.__index = P

local PARACHUTE = 46
local PARACHUTE_SLOT = 11
local EQUIP_PLAYER_WEAPON = 0x60B460
local FALL_ANIMATIONS = {
    'FALL_skyDive', 'FALL_SkyDive_Accel', 'FALL_skyDive_DIE',
    'FALL_skyDive_L', 'FALL_skyDive_R', 'PARA_open', 'PARA_float',
}

local function input_allowed()
    return not sampIsChatInputActive() and not sampIsDialogActive()
        and not sampIsCursorActive() and not isPauseMenuActive()
        and not isSampfuncsConsoleActive() and not MainWindow:is_open()
        and (not isPlayerControlLocked or not isPlayerControlLocked())
        and (not isGameWindowForeground or isGameWindowForeground())
end

local function falling()
    for _, anim in ipairs(FALL_ANIMATIONS) do
        if isCharPlayingAnim(PLAYER_PED, anim) then return true end
    end
    return false
end

local function next_weapon(direction)
    for offset = 1, 12 do
        local slot = (PARACHUTE_SLOT + direction * offset) % 13
        if slot == 0 then return 0 end -- Fists are always available.
        local weapon, ammo = getCharWeaponInSlot(PLAYER_PED, slot + 1)
        if weapon > 0 and weapon ~= PARACHUTE and (ammo > 0 or slot == 1 or slot == 10 or slot == 12) then
            return weapon
        end
    end
    return 0
end

local function equip(weapon)
    -- 01B9 only queues a player weapon. On the verified GTA US build, use the
    -- same equip routine as GTA's weapon cycle and check its live code first.
    if callMethod and getCharPointer and readMemory
        and readMemory(EQUIP_PLAYER_WEAPON, 4, false) == 0x0FF18B56
        and readMemory(EQUIP_PLAYER_WEAPON + 4, 4, false) == 0x071886BE
        and bit.tobit(readMemory(EQUIP_PLAYER_WEAPON + 0x38, 4, false) or 0) == bit.tobit(0xFDADE3E8)
        and readMemory(0x5E61F0, 4, false) == 0x245C8B53
        and readMemory(0x5E6230, 4, false) == 0x07189E88 then
        local ped = getCharPointer(PLAYER_PED)
        if ped and ped ~= 0 then
            callMethod(EQUIP_PLAYER_WEAPON, ped, 1, 0, weapon)
            return
        end
    end
    setCurrentCharWeapon(PLAYER_PED, weapon)
end

function P.new(enabled, on_skip)
    return setmetatable({enabled = enabled, on_skip = on_skip, frame = 0}, P)
end

function P:input(direction)
    self.intent = {direction = direction, ready = self.frame + 2, at = os.clock()}
end

function P:window(message, wparam, lparam)
    if not self.enabled[0] then return end
    local direction
    if message == 0x20A then
        local delta = bit.rshift(wparam, 16)
        if delta >= 32768 then delta = delta - 65536 end
        if delta ~= 0 then direction = delta > 0 and -1 or 1 end
    elseif (message == 0x100 or message == 0x104) and bit.band(lparam or 0, 0x40000000) == 0 then
        if wparam == 0x51 then direction = -1 end
        if wparam == 0x45 then direction = 1 end
    end
    if direction and input_allowed() then
        self.window_frame = self.frame
        self:input(direction)
    end
end

function P:poll_controls()
    local left = isButtonPressed and isButtonPressed(PLAYER_HANDLE, keys.CYCLEWEAPONLEFT_SNIPERZOOMIN)
    local right = isButtonPressed and isButtonPressed(PLAYER_HANDLE, keys.CYCLEWEAPONRIGHT_SNIPERZOOMOUT)
    local q = isKeyDown and isKeyDown(0x51)
    local e = isKeyDown and isKeyDown(0x45)
    local wheel = getMousewheelDelta and getMousewheelDelta() or 0
    local direction
    if (left and not self.left) or (q and not self.q) then
        direction = -1
    elseif (right and not self.right) or (e and not self.e) then
        direction = 1
    elseif wheel ~= 0 then
        direction = wheel > 0 and -1 or 1
    end
    self.left, self.right, self.q, self.e = left, right, q, e
    return direction
end

function P:tick()
    self.frame = self.frame + 1
    if not self.enabled[0] or not doesCharExist(PLAYER_PED) or sampGetGamestate() ~= 3
        or not sampIsLocalPlayerSpawned() or isCharInAnyCar(PLAYER_PED)
        or (isCharDead and isCharDead(PLAYER_PED)) or (isCharInWater and isCharInWater(PLAYER_PED)) then
        self.intent, self.selection, self.last_weapon = nil, nil, nil
        return
    end
    local direction = self:poll_controls()
    if not input_allowed() then
        self.intent, self.selection, self.last_weapon = nil, nil, nil
        return
    end
    local current = getCurrentCharWeapon(PLAYER_PED)
    local previous = self.last_weapon
    self.last_weapon = current
    if current ~= PARACHUTE and getCharWeaponInSlot(PLAYER_PED, PARACHUTE_SLOT + 1) ~= PARACHUTE then
        self.intent, self.selection = nil, nil
        return
    end
    if falling() then
        self.intent, self.selection = nil, nil
        if current ~= PARACHUTE then equip(PARACHUTE) end
        return
    end

    local selection = self.selection
    if selection then
        if current == selection.weapon and os.clock() < selection.expires then
            self.on_skip()
        elseif current == PARACHUTE and os.clock() < selection.expires then
            return
        end
        self.selection = nil
    end

    -- A wheel notch can arrive through both paths. Preserve the window
    -- event's timing and use polling if no window event arrived.
    if direction and self.window_frame ~= self.frame - 1
        and (not self.intent or self.intent.direction ~= direction) then
        self:input(direction)
    end
    local intent = self.intent
    if not intent then return end
    if os.clock() - intent.at > 0.35 then self.intent = nil; return end
    -- The real weapon transition confirms that GTA processed the cycle. Skip
    -- immediately on that frame, as PEMENU does. If we were already holding
    -- the parachute, give the original input time to move off it on its own.
    local reached_chute = current == PARACHUTE and previous ~= nil and previous ~= PARACHUTE
    if not reached_chute and self.frame < intent.ready then return end
    if current ~= PARACHUTE then
        -- The original control may take another frame to reach the chute.
        if self.frame >= intent.ready + 2 then self.intent = nil end
        return
    end

    self.intent = nil
    local weapon = next_weapon(intent.direction)
    equip(weapon)
    if getCurrentCharWeapon(PLAYER_PED) == weapon then
        self.last_weapon = weapon
        self.on_skip()
    else
        self.selection = {weapon = weapon, expires = os.clock() + 0.25}
    end
end

function P:register(event_handler)
    addEventHandler('onWindowMessage', function(...) self:window(...) end)
    event_handler:register('PED_TICK', function() return true end, function() self:tick() end)
end

return P
