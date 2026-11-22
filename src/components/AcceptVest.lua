-- Module: F:\2025\EDrive\dev\luapack\src\components\AcceptVest.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")
local Timer = require("src.core.Timer")
local Rules = require("src.core.Rules")
local VestRules=require('src.core.VestRules')

local ACCEPT_VEST = {
    DEFAULT_PRICE = 200,
    MIN_ARMOUR_THRESHOLD = 50.0,
    MAX_PLAYER_DISTANCE = 5.5,
    RETRY_TIMER_SECONDS = 2,
}

local CONFIG_PATH = "config/Leone Menu/acceptvest.json"

local default_data = {
    accept_below = imgui.new.int(50),
    manual = {enabled=imgui.new.bool(true),keys={}},
    should_disable_after_point = imgui.new.bool(true),
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.595,
        14,
        6,
        1,
        2,
        true,
        { 0, 0, 0, 0.588 },
        true,
        { 0, 0, 0, 0.588 }
    ),
}

local _config = default_data

local _accept_vest_state = {
    is_enabled = imgui.new.bool(false),
    retry_timer = Timer.new(imgui.new.int(ACCEPT_VEST.RETRY_TIMER_SECONDS)),
    pending_offer_from_id = -1,
    pending_offer_nickname = "No-one",
    pending_offer_price = ACCEPT_VEST.DEFAULT_PRICE,
}

local _auto_faid = {
    is_enabled = imgui.new.bool(false),
    next_use_at = nil,
}

local function _use_auto_faid()
    if not _auto_faid.is_enabled[0] or not _auto_faid.next_use_at
        or os.clock() < _auto_faid.next_use_at
        or sampGetGamestate() ~= 3 or not sampIsLocalPlayerSpawned()
        or getCharHealth(PLAYER_PED) <= 0 then
        return
    end
    _auto_faid.next_use_at = nil
    sampSendChat('/faid')
end

local function _set_auto_faid(enabled)
    _auto_faid.is_enabled[0] = enabled
    _auto_faid.next_use_at = enabled and os.clock() or nil
    _use_auto_faid()
end

local function _set_pending_offer(from_id, price)
    _accept_vest_state.pending_offer_from_id = from_id
    _accept_vest_state.pending_offer_price = price

    if from_id == -1 or not sampIsPlayerConnected(from_id) then
        _accept_vest_state.pending_offer_nickname = "No-one"
        return
    end

    _accept_vest_state.pending_offer_nickname = sampGetPlayerNickname(from_id)
end

local function _handle_ped_tick(x, y, z)
    _use_auto_faid()
    if not VestRules.can_accept() then _set_pending_offer(-1,ACCEPT_VEST.DEFAULT_PRICE);return end
    if not _accept_vest_state.is_enabled[0] then
        return
    end

    if _accept_vest_state.pending_offer_from_id == -1 then
        return
    end

    if not _accept_vest_state.retry_timer:is_ready() then
        return
    end

    if _accept_vest_state.pending_offer_price ~= ACCEPT_VEST.DEFAULT_PRICE then
        return
    end

    if getPlayerMoney(PLAYER_HANDLE) < ACCEPT_VEST.DEFAULT_PRICE then
        return
    end

    if getCharArmour(PLAYER_PED) >= _config.accept_below[0] then
        return
    end

    if isCharPlayingAnim(PLAYER_PED, "KILL_Knife_Ped_Die") then
        return
    end

    local found, id = Player:get_closest_player_id(
        ACCEPT_VEST.MAX_PLAYER_DISTANCE,
        { function(id) return id == _accept_vest_state.pending_offer_from_id end }
    )

    if not found then
        return
    end

    _accept_vest_state.retry_timer:trigger()
    sampSendChat("/accept bodyguard")
end

local function _register_event_handlers()

    shared.event_handler:register(
        'SERVER_MESSAGE',
        function(_, text)
            if not _auto_faid.is_enabled[0] then return false end
            local message = text:gsub('{%x%x%x%x%x%x}', ''):match('^%s*(.-)%s*$')
            return message == 'Your first aid kit no longer takes effect.'
                or message == 'Your first aid kit has been stopped, because you were damaged by another player.'
        end,
        function(_, text)
            if text:find('damaged by another player', 1, true) then
                _auto_faid.next_use_at = os.clock() + 15
            else
                _auto_faid.next_use_at = _auto_faid.next_use_at or os.clock()
                _use_auto_faid()
            end
        end
    )

    shared.event_handler:register('SERVER_CONNECTED', function() return true end, function()
        _set_auto_faid(false)
    end)

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.LIGHTBLUE then
                local player_name, price = text:match(
                    "^%* Bodyguard (.-) wants to protect you for %$(%d+), type %/accept bodyguard to accept%.$"
                )
                if player_name and price then
                    return { player_name, tonumber(price) }
                end
            end
            return false
        end,
        function(player_name, price)
            if not VestRules.can_accept() then _set_pending_offer(-1,ACCEPT_VEST.DEFAULT_PRICE);return end
            local raw_name = player_name:gsub(" ", "_")
            local player_id = Player:get_player_id_by_name(raw_name)

            if not player_id then
                return
            end

            _set_pending_offer(player_id, price)
            _accept_vest_state.retry_timer:trigger()

            if _accept_vest_state.is_enabled[0]
                and getCharArmour(PLAYER_PED) < _config.accept_below[0]
                and not isCharPlayingAnim(PLAYER_PED, "KILL_Knife_Ped_Die")
                and getPlayerMoney(PLAYER_HANDLE) >= ACCEPT_VEST.DEFAULT_PRICE
                and price == ACCEPT_VEST.DEFAULT_PRICE
            then
                sampSendChat("/accept bodyguard")
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.LIGHTBLUE then
                return text:match("^%* You accepted the protection for %$%d+ from .-%.$") ~= nil
            end
            return false
        end,
        function()
            _set_pending_offer(-1, ACCEPT_VEST.DEFAULT_PRICE)
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW
                and (_accept_vest_state.is_enabled[0] or _auto_faid.is_enabled[0])
                and _config.should_disable_after_point[0]
            then
                local point, captured_by = text:match("^.- has taken control of (.-) for (.-)%.$")
                if point and captured_by and point:lower():match("^the ") then
                    return true
                end
            end
            return false
        end,
        function()
            local vest_enabled = _accept_vest_state.is_enabled[0]
            local faid_enabled = _auto_faid.is_enabled[0]
            _accept_vest_state.is_enabled[0] = false
            _set_auto_faid(false)
            local label = vest_enabled and 'Auto Accept Vest' or 'Auto First Aid'
            if vest_enabled and faid_enabled then label = 'Auto Accept Vest and Auto First Aid' end
            shared.notification:show(
                label .. " disabled as the point is over.",
                shared.notification.types.INFO
            )
        end
    )

    shared.event_handler:register(
        "PLAYER_QUIT",
        function(player_id, reason)
            return _accept_vest_state.pending_offer_from_id == player_id
        end,
        function()
            _set_pending_offer(-1, ACCEPT_VEST.DEFAULT_PRICE)
        end
    )

    shared.event_handler:register(
        "PLAYER_JOIN",
        function(player_id, color, is_npc, nick)
            return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == player_id
        end,
        function()
            _set_pending_offer(-1, ACCEPT_VEST.DEFAULT_PRICE)
        end
    )

    shared.event_handler:register(
        "PED_TICK",
        function(x, y, z) return { x, y, z } end,
        _handle_ped_tick
    )
end

local function _register_commands()
    sampRegisterChatCommand('afaid', function()
        _set_auto_faid(not _auto_faid.is_enabled[0])
        msg(string.format('Auto First Aid has been %s{FFFFFF}.',
            _auto_faid.is_enabled[0] and '{00FF00}enabled' or '{FF0000}disabled'))
    end)
    sampRegisterChatCommand(
        "av",
        function()
            _accept_vest_state.is_enabled[0] = not _accept_vest_state.is_enabled[0]

            msg(string.format(
                "Auto Accept Vest has been %s{FFFFFF}.",
                _accept_vest_state.is_enabled[0] and "{00FF00}enabled" or "{FF0000}disabled"
            ))
        end
    )
end

local AcceptVest = {}

function AcceptVest:get_pending_offer()
    if _accept_vest_state.pending_offer_from_id==-1 then return nil end
    return {id=_accept_vest_state.pending_offer_from_id,name=_accept_vest_state.pending_offer_nickname,price=_accept_vest_state.pending_offer_price}
end

function AcceptVest:get_offer_sender_name()
    return _accept_vest_state.pending_offer_nickname
end

function AcceptVest:register()
    carboneum.load(CONFIG_PATH, _config)
    VestRules.register()

    _register_event_handlers()
    _register_commands()

    shared.hotkey_manager:register('manual_accept_vest',_config.manual.keys,function()
        if _config.manual.enabled[0] and VestRules.can_accept() then
            sampSendChat('/accept bodyguard')
        end
    end)
    shared.event_handler:register('HOSPITAL_ADMITTED',function()return true end,function()
        _set_pending_offer(-1,ACCEPT_VEST.DEFAULT_PRICE)
    end)
end

function AcceptVest:get_config()
    return _config
end

function AcceptVest:get_overlay_config()
    return _config.overlay
end

function AcceptVest:save_config()
    return carboneum.save(CONFIG_PATH, _config)
end

function AcceptVest:render_ui_settings()
    local H=require('src.ui.Helpers')
    imgui.DrawChild('Accept Vest',function(width)
        H.toggle('Automatically accept vest offers priced at $200 - /av','accept_vest',_accept_vest_state.is_enabled,width)
        imgui.Separator()
        local faid_tip = 'Uses /faid immediately, then again as soon as the current first aid kit wears off.\nWaits 15 seconds if another player damages you.\nStops when the point is over with the point-completion stop enabled.'
        if H.toggle('Automatically use faid - /afaid', 'auto_faid', _auto_faid.is_enabled, width, faid_tip) then
            _set_auto_faid(_auto_faid.is_enabled[0])
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('%s', faid_tip) end
        imgui.Separator()
        imgui.Text('Accept if vest is below');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##accept_below',_config.accept_below);_config.accept_below[0]=math.max(0,math.min(100,_config.accept_below[0]))
        imgui.Separator()
        H.toggle('Manual Accept','manual_accept_enable',_config.manual.enabled,width)
        imgui.Separator()
        H.bind('Manually accept vest','manual_accept_vest',_config.manual,width)
        imgui.Separator()
        H.toggle('Automatically stop accepting vest offers upon point completion','disable_after_point',_config.should_disable_after_point,width)
        imgui.Separator()
        H.toggle('Show offered-by overlay','offered_by',_config.overlay.display,width)
    end)
end
return AcceptVest
