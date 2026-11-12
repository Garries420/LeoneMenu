-- Skip an actually selected parachute using the player's existing weapons.
local bit = require('bit')
local keys = require('game.keys').player
local MainWindow = require('src.ui.MainWindow')
local P = {}
P.__index = P

local PARACHUTE = 46
local PARACHUTE_SLOT = 11
local EQUIP_PLAYER_WEAPON = 0x60B460
local AIRCRAFT_EXIT_SECONDS = 2
local SELECTION_RETRY_SECONDS = 0.25
local FALL_ANIMATIONS = {
    'FALL_skyDive', 'FALL_SkyDive_Accel', 'FALL_skyDive_DIE',
    'FALL_skyDive_L', 'FALL_skyDive_R', 'PARA_open', 'PARA_open_O',
    'PARA_float', 'PARA_float_O', 'PARA_decel', 'PARA_decel_O',
    'PARA_steerL', 'PARA_steerL_O', 'PARA_steerR', 'PARA_steerR_O',
}

local function input_allowed()
    return not sampIsChatInputActive() and not sampIsDialogActive()
        and not sampIsCursorActive() and not isPauseMenuActive()
        and not isSampfuncsConsoleActive() and not MainWindow:is_open()
        and (not isPlayerControlLocked or not isPlayerControlLocked())
        and (not isGameWindowForeground or isGameWindowForeground())
end

local function falling()
    -- Catch a bail-out or drop before GTA blends into the skydiving animation.
    -- Height and downward movement keep an ordinary jump on the ground path.
    if isCharInAir and getCharHeightAboveGround and getCharVelocity and isCharInAir(PLAYER_PED)
        and getCharHeightAboveGround(PLAYER_PED) >= 2.1 then
        local _, _, vertical_speed = getCharVelocity(PLAYER_PED)
        if vertical_speed < 0 then return true end
    end
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
    self.last_direction = direction
    self.cycle_ready = self.frame + 2
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
        or not sampIsLocalPlayerSpawned()
        or (isCharDead and isCharDead(PLAYER_PED)) or (isCharInWater and isCharInWater(PLAYER_PED)) then
        self.cycle_ready, self.selection, self.last_weapon, self.last_direction = nil, nil, nil, nil
        self.in_aircraft, self.aircraft_exit_until = nil, nil
        return
    end
    if isCharInAnyCar(PLAYER_PED) then
        self.in_aircraft = isCharInFlyingVehicle and isCharInFlyingVehicle(PLAYER_PED)
        self.cycle_ready, self.selection, self.last_weapon, self.last_direction = nil, nil, nil, nil
        self.aircraft_exit_until = nil
        return
    end
    local now = os.clock()
    if self.in_aircraft then self.aircraft_exit_until = now + AIRCRAFT_EXIT_SECONDS end
    self.in_aircraft = nil
    local aircraft_exit = self.aircraft_exit_until and now < self.aircraft_exit_until
    if not aircraft_exit then self.aircraft_exit_until = nil end

    local direction = self:poll_controls()
    if not input_allowed() then
        self.cycle_ready, self.selection, self.last_weapon = nil, nil, nil
        return
    end
    -- A wheel notch can arrive through both paths. Keep the window event's
    -- direction if polling sees the same input on this frame.
    if direction and self.window_frame ~= self.frame - 1 then self:input(direction) end

    local current = getCurrentCharWeapon(PLAYER_PED)
    local previous = self.last_weapon
    self.last_weapon = current
    if current ~= PARACHUTE and getCharWeaponInSlot(PLAYER_PED, PARACHUTE_SLOT + 1) ~= PARACHUTE then
        self.selection = nil
        return
    end
    if falling() then
        self.cycle_ready, self.selection = nil, nil
        if aircraft_exit then self.aircraft_exit_until = now + AIRCRAFT_EXIT_SECONDS end
        -- Leave GTA's current selection alone while falling.
        return
    end

    local selection = self.selection
    if selection then
        if current == selection.weapon then
            self.aircraft_exit_until = nil
            self.on_skip()
        elseif current == PARACHUTE and now < selection.retry_at then
            return
        end
        self.selection = nil
    end
    if current ~= PARACHUTE then return end

    -- A newly selected chute confirms the cycle happened. If it was already
    -- held, give a fresh input one frame to cycle away on its own.
    local reached_chute = current == PARACHUTE and previous ~= nil and previous ~= PARACHUTE
    if not aircraft_exit and not reached_chute and self.cycle_ready and self.frame < self.cycle_ready then return end
    self.cycle_ready = nil

    local weapon = 0
    if not aircraft_exit then
        if self.last_direction then
            weapon = next_weapon(self.last_direction)
        elseif previous ~= nil and previous ~= PARACHUTE then
            -- PEMENU uses the previously active slot when there was no input.
            local left, right = next_weapon(-1), next_weapon(1)
            if previous == left then weapon = right
            elseif previous == right then weapon = left end
        end
    end

    equip(weapon)
    if getCurrentCharWeapon(PLAYER_PED) == weapon then
        self.last_weapon = weapon
        self.aircraft_exit_until = nil
        self.on_skip()
    else
        self.selection = {weapon = weapon, retry_at = now + SELECTION_RETRY_SECONDS}
    end
end

function P:register(event_handler)
    addEventHandler('onWindowMessage', function(...) self:window(...) end)
    event_handler:register('PED_TICK', function() return true end, function() self:tick() end)
end

return P
