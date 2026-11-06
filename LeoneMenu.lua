-- LEONE_MENU_BUNDLE
-- Leone Menu is built on Sputnik by Kev and Futurestunt. Modified by Garry.
-- Original supplied source is preserved in the development workspace.
package.preload['upmimgui'] = function() return require('leone.upmimgui') end

package.preload['src.components.AcceptVest'] = function()
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

local ACCEPT_VEST = {
    DEFAULT_PRICE = 200,
    MIN_ARMOUR_THRESHOLD = 50.0,
    MAX_PLAYER_DISTANCE = 5.5,
    RETRY_TIMER_SECONDS = 2,
}

local CONFIG_PATH = "config/Leone Menu/acceptvest.json"
local OUTSIDE_POINT_MESSAGE = "You can't heal if you were recently shot, except within points, events, minigames, and paintball."

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
        "SERVER_MESSAGE",
        function(color,text)
            return _accept_vest_state.is_enabled[0] and Rules.strip(text)==OUTSIDE_POINT_MESSAGE
        end,
        function()
            _accept_vest_state.is_enabled[0]=false
            msg("Not at point detected, Auto Vest has been turned {FF0000}OFF")
        end
    )

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
                and _accept_vest_state.is_enabled[0]
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
            _accept_vest_state.is_enabled[0] = false
            shared.notification:show(
                "Auto Accept Vest has been disabled as the point is over.",
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

    _register_event_handlers()
    _register_commands()

    shared.hotkey_manager:register('manual_accept_vest',_config.manual.keys,function()
        if _config.manual.enabled[0] then
            sampSendChat('/accept bodyguard')
        end
    end)
end

function AcceptVest:get_config()
    return _config
end

function AcceptVest:get_overlay_config()
    return _config.overlay
end

function AcceptVest:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function AcceptVest:render_ui_settings()
    local H=require('src.ui.Helpers')
    imgui.DrawChild('Accept Vest',function(width)
        H.toggle('Automatically accept vest offers priced at $200 - /av','accept_vest',_accept_vest_state.is_enabled,width)
        imgui.Text('Accept if vest is below');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##accept_below',_config.accept_below);_config.accept_below[0]=math.max(0,math.min(100,_config.accept_below[0]))
        H.toggle('Manual Accept','manual_accept_enable',_config.manual.enabled,width)
        H.bind('Manually accept vest','manual_accept_vest',_config.manual,width)
        H.toggle('Automatically stop accepting vest offers upon point completion','disable_after_point',_config.should_disable_after_point,width)
        H.toggle('Show offered-by overlay','offered_by',_config.overlay.display,width)
    end)
end
return AcceptVest

end

package.preload['src.components.AutoVest'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\AutoVest.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local keys = require("game.keys")

local AsyncHttpRequest = require("src.utils.AsyncHttpRequest")
local Updates = require("src.core.Updates")
local H = require("src.ui.Helpers")
local Rules = require("src.core.Rules")
local Editor = require("src.ui.AllianceEditor")
local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")
local Timer = require("src.core.Timer")

local COMMAND_MODE = {
    NORMAL = 0,
    DD = 1,
}

local VESTER_MODE = { AUTOMATIC = 0, MANUAL = 1 }

local CONFIG_PATH = "config/Leone Menu/autovest.json"

local default_data = {
    is_enabled = imgui.new.bool(true),
    command_mode = {
        current = imgui.new.int(COMMAND_MODE.NORMAL),
        intervals = {
            [COMMAND_MODE.NORMAL] = imgui.new.int(13),
            [COMMAND_MODE.DD] = imgui.new.int(10),
        },
    },
    vester_mode = imgui.new.int(VESTER_MODE.AUTOMATIC),
    offer_if_armor_below = imgui.new.int(48),
    groups = {},
    aim = {keys={}},
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.56,
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
default_data.overlay.only_show_during_countdown = imgui.new.bool(false)

local _config = default_data

local _auto_vest_state = {
    timers = {
        [COMMAND_MODE.NORMAL] = Timer.new(_config.command_mode.intervals[COMMAND_MODE.NORMAL]),
        [COMMAND_MODE.DD] = Timer.new(_config.command_mode.intervals[COMMAND_MODE.DD]),
    },
    last_vest_recipient_name = "None",
    pending = nil,
    cooldown_until = 0,
    aim_request = nil,
}

local _ui_state = {
    input_fields = {
        friend = "",
        skins = "",
    },
}

local function _get_active_timer()
    return _auto_vest_state.timers[_config.command_mode.current[0]]
end

local function _aim_is_held()
    return is_aiming() or (not isCharInAnyCar(PLAYER_PED) and isButtonPressed and isButtonPressed(PLAYER_HANDLE,keys.player.LOCKTARGET))
end
local function _process_aim_request()
    local request=_auto_vest_state.aim_request
    if not request then return end
    local function cancel()_auto_vest_state.aim_request=nil end
    if not sampIsLocalPlayerSpawned() or sampGetGamestate()~=3 or is_cursor_active()
        or sampIsChatInputActive() or sampIsDialogActive() or isPauseMenuActive()
        or MainWindow:is_open() or (isGameWindowForeground and not isGameWindowForeground())
        or not sampIsPlayerConnected(request.id) or sampGetPlayerNickname(request.id)~=request.name then
        cancel();return
    end
    if _aim_is_held()then request.released_at=nil;return end
    request.released_at=request.released_at or os.clock()
    -- Let the released aim state reach SA-MP before sending the guard command.
    if os.clock()-request.released_at<0.1 then return end
    local connected,ped=sampGetCharHandleBySampPlayerId(request.id)
    if not connected or not doesCharExist(ped) then cancel();return end
    local x,y,z=getCharCoordinates(PLAYER_PED)
    local tx,ty,tz=getCharCoordinates(ped)
    cancel()
    if not is_within_distance_3d(x,y,z,tx,ty,tz,6)then return end
    _get_active_timer():set_temp_interval(3)
    sampSendChat(string.format('/guard %d 200',request.id))
end

local function _find_closest_valid_player()

    if _aim_is_held() then
        return nil
    end

    local local_pos_x, local_pos_y, local_pos_z = getCharCoordinates(PLAYER_PED)
    local max_dist = 6
    local closest = nil

    local function is_valid_player(player, id)
        local name = sampGetPlayerNickname(id)

        if not name:find("_") then
            return false
        end

        local skin=getCharModel(player)
        local match=_config.vester_mode[0]==VESTER_MODE.AUTOMATIC and Updates.is_alliance(skin)
        if _config.vester_mode[0]==VESTER_MODE.MANUAL then
            for _,group in ipairs(_config.groups) do
                for _,v in ipairs(group.skins) do if v==skin then match=true end end
            end
        end
        if not match then return false end

        if sampIsPlayerPaused(id) or isCharPlayingAnim(player, "KILL_Knife_Ped_Die") then
            return false
        end

        local armor = sampGetPlayerArmor(id)
        if armor > _config.offer_if_armor_below[0] then
            return false
        end

        local x, y, z = getCharCoordinates(player)
        if not is_within_distance_3d(x, y, z, local_pos_x, local_pos_y, local_pos_z, max_dist) then
            return false
        end

        return {
            player_id = id,
            distance = math.sqrt((x - local_pos_x) ^ 2 + (y - local_pos_y) ^ 2 + (z - local_pos_z) ^ 2),
            armor = armor,
            health = sampGetPlayerHealth(id),
            ped = player
        }
    end

    for id = 0, sampGetMaxPlayerId(true) do
        if sampIsPlayerConnected(id) then
            local ok, ped = sampGetCharHandleBySampPlayerId(id)

            if ok then
                local player_data = is_valid_player(ped, id)

                if player_data then
                    if not closest then
                        closest = player_data
                    else
                        local cmd_mode = _config.command_mode.current[0]
                        local diff1 = math.abs(player_data.armor - 50)
                        local diff2 = math.abs(closest.armor - 50)
                        local replace = false

                        if cmd_mode == COMMAND_MODE.NORMAL then
                            if diff1 > diff2 + 5 then
                                replace = true
                            elseif math.abs(diff1 - diff2) <= 5 then
                                if player_data.health < closest.health or
                                    (player_data.health == closest.health and player_data.distance < closest.distance) then
                                    replace = true
                                end
                            end
                        elseif player_data.distance < closest.distance then
                            replace = true
                        end

                        if replace then
                            closest = player_data
                        end
                    end
                end
            end
        end
    end

    return closest
end

local function _handle_ped_tick()
    local target = _find_closest_valid_player()
    if not target then
        return
    end

    _get_active_timer():set_temp_interval(3)

    local cmd_mode = _config.command_mode.current[0]
    local command = cmd_mode == COMMAND_MODE.NORMAL and "guard" or "guardnear"

    sampSendChat(string.format("/%s %d 200", command, target.player_id))
end

local function _register_event_handlers()
    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.LIGHTBLUE and
                text == "* You are now a Bodyguard, type /help to see your new commands."
        end,
        function()
            _auto_vest_state.timers[COMMAND_MODE.NORMAL]:resume()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.GREY and text == "You are not a bodyguard."
        end,
        function()
            _auto_vest_state.timers[COMMAND_MODE.NORMAL]:pause()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.LIGHTBLUE then
                local player_name = text:match("^%* You offered protection to (.-) for $%d+%.$")
                if player_name then
                    return { player_name }
                end
            end
            return false
        end,
        function(player_name)
            _auto_vest_state.last_vest_recipient_name = player_name
            _auto_vest_state.pending={name=player_name,id=Player:get_player_id_by_name(player_name:gsub(" ","_")),price=200}
            local timer=_get_active_timer()
            timer:trigger()
            _auto_vest_state.cooldown_until=os.clock()+timer:get_active_interval()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.GREY then
                local cooldown = text:match("^   You must wait (%d+) seconds before selling another vest%.$")
                if cooldown then
                    return { cooldown }
                end
            end
            return false
        end,
        function(cooldown)
            local seconds=tonumber(cooldown)+2
            _get_active_timer():set_temp_interval(seconds)
            _auto_vest_state.cooldown_until=math.max(_auto_vest_state.cooldown_until,os.clock()+seconds)
        end
    )

    shared.event_handler:register(
        "PED_TICK",
        function(x, y, z)
            return _config.is_enabled[0] and not _auto_vest_state.aim_request and _get_active_timer():is_ready()
        end,
        _handle_ped_tick
    )
end

local function _register_commands()
    sampRegisterChatCommand(
        "avest",
        function()
            _config.is_enabled[0] = not _config.is_enabled[0]
            msg(string.format("Auto Vest has been %s{FFFFFF}.",
                _config.is_enabled[0] and "{00FF00}enabled" or "{FF0000}disabled"))
        end
    )

    sampRegisterChatCommand('avmode',function(args)
        local modes={automatic=0,manual=1}
        if modes[args]==nil then return msg('USAGE: /avmode automatic/manual') end
        _config.vester_mode[0]=modes[args]
    end)

    sampRegisterChatCommand(
        "ddmode",
        function()
            local old_mode = _config.command_mode.current[0]
            local modes_reverse = {
                [COMMAND_MODE.NORMAL] = "Normal",
                [COMMAND_MODE.DD] = "DD"
            }

            _config.command_mode.current[0] = old_mode == COMMAND_MODE.DD and COMMAND_MODE.NORMAL or COMMAND_MODE.DD

            msg(string.format(
                "Vester Command Mode has been switched to '%s' mode (Previous: '%s' mode)",
                modes_reverse[_config.command_mode.current[0]], modes_reverse[old_mode]
            ))
        end
    )
end

local AutoVest = {}

function AutoVest:get_pending_offer() return _auto_vest_state.pending end

function AutoVest:get_timer()
    return _get_active_timer()
end

function AutoVest:get_cooldown_remaining()
    return math.max(0,math.ceil(_auto_vest_state.cooldown_until-os.clock()))
end

function AutoVest:get_last_recipient()
    return _auto_vest_state.last_vest_recipient_name
end

function AutoVest:register()
    carboneum.load(CONFIG_PATH, _config)

    _register_event_handlers()
    _register_commands()
    shared.hotkey_manager:register('aim_vest',_config.aim.keys,function()
        local ok,ped=getCharPlayerIsTargeting(PLAYER_HANDLE)
        if not ok or not doesCharExist(ped) then return end
        local connected,id=sampGetPlayerIdByCharHandle(ped)
        if connected then _auto_vest_state.aim_request={id=id,name=sampGetPlayerNickname(id)} end
    end)
    shared.event_handler:register('PED_TICK',function()return _auto_vest_state.aim_request~=nil end,_process_aim_request)
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)
        local offer=_auto_vest_state.pending
        if not offer then return false end
        local plain=Rules.strip(text)
        local name=plain:match('^%* (.-) accepted your protection%.$')
            or plain:match('^%* (.-) accepted your protection, and the %$[%d,]+ was added to your money%.$')
        return name and name:gsub('_',' '):lower()==offer.name:gsub('_',' '):lower()
    end,function()
        _auto_vest_state.pending=nil
        _auto_vest_state.cooldown_until=0
    end)

    MainWindow:add_page("auto_vest", {
        icon = fa("VEST"),
        title = "Auto Vest",
        icon_box_color = imgui.ImVec4(0.5, 0.3, 0.7, 1),
        render_function = function()
            if AutoVest.render_ui_settings then
                AutoVest:render_ui_settings()
            end
        end
    })
end

function AutoVest:get_config()
    return _config
end

function AutoVest:get_overlay_config()
    return _config.overlay
end

function AutoVest:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function AutoVest:render_ui_settings()
    imgui.DrawChild('Auto Vest',function(width)
        H.toggle('Automatically vest nearby players - /avest','auto_vest',_config.is_enabled,width)
        H.bind('Aim and vest','aim_vest',_config.aim,width)
        imgui.Separator()
        imgui.Text('Command mode');imgui.SameLine(width-250)
        imgui.SegmentedControl('command_mode',{'Normal','DD'},_config.command_mode.current,imgui.ImVec2(250,0))
        imgui.Separator()
        imgui.Text('Alliance skins to be vested');imgui.SameLine(width-290)
        if imgui.AnimButton(fa('GEAR')) then Editor:show(_config.groups,function()self:save_config()end) end
        imgui.SameLine(width-250)
        imgui.SegmentedControl('alliance_mode',{'Automatic','Manual'},_config.vester_mode,imgui.ImVec2(250,0))
        if imgui.IsItemHovered() then imgui.SetTooltip('Automatic grabs Leone alliance skins; it can be outdated for 1-2 days. Use Manual in the meantime. Manual uses the groups added in the cogwheel.') end
        imgui.Text('Vest interval (seconds)');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##vest_interval',_config.command_mode.intervals[_config.command_mode.current[0]])
        local interval=_config.command_mode.intervals[_config.command_mode.current[0]];interval[0]=math.max(1,interval[0])
        imgui.Text('Offer if vest is below');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##offer_below',_config.offer_if_armor_below);_config.offer_if_armor_below[0]=math.max(0,math.min(100,_config.offer_if_armor_below[0]))
        H.toggle('Show offered-to overlay','offered_to',_config.overlay.display,width)
    end)
    require('src.components.AcceptVest'):render_ui_settings()
    H.position({_config.overlay},'vesting')
    Editor:render()
end
return AutoVest

end

package.preload['src.components.Backup'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\Backup.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")

local CONFIG_PATH = "config/Leone Menu/backup.json"

local default_data = {
    overlay = Overlay.setup_overlay_defaults(
        false,
        0.943,
        0.487,
        12,
        8,
        5,
        4,
        true,
        { 0, 0, 0, 0.588 },
        true,
        { 0, 0, 0, 0.588 }
    ),
}

default_data.wanted=imgui.new.bool(false)
default_data.bind={keys={}}
local H=require('src.ui.Helpers')
local shared=require('src.shared')
local locations=require('src.core.CustomLocations')
local show_locations=false

local _config = default_data

local Backup = {}

function Backup:is_requesting(player_id)
    if not sampIsPlayerConnected(player_id) then
        return false
    end

    local color = sampGetPlayerColor(player_id)
    local alpha = bit.rshift(color, 24)

    return alpha == 0xAA
end

function Backup:register()
    carboneum.load(CONFIG_PATH, _config)

    shared.hotkey_manager:register('faction_backup',_config.bind.keys,function()
        local x,y,z=getCharCoordinates(PLAYER_PED)
        local interior=getActiveInterior()
        local special=locations.find(x,y,z,interior)
        local place
        if interior==0 then
            local zone=require('src.utils.ZoneManager'):get_zone(x,y)
            place=special and (special.name..', '..zone) or zone
        else
            place=special and special.name or 'Interior'
        end
        local suffix=''
        if _config.wanted[0] then
            -- MoonLoader opcode 01C0 returns a result flag before the level.
            local _,stars=storeWantedLevel(PLAYER_HANDLE)
            if type(stars)=='number' and stars>=1 and stars<=6 and stars%1==0 then
                suffix=" I'm wanted with "..stars..(stars==1 and ' star' or ' stars')
            end
        end
        sampSendChat('/pr I need urgent backup! Currently at '..place..'!'..suffix)
    end)
    MainWindow:add_page("backup", {
        icon = fa("BULLHORN"),
        title = "Backup",
        icon_box_color = imgui.ImVec4(0.95, 0.5, 0.2, 1),
        prepare_search = function() show_locations=false end,
        render_function = Backup.render_ui_settings
    })
end

function Backup:get_config()
    return _config
end

function Backup:get_overlay_config()
    return _config.overlay
end

function Backup:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function Backup:render_ui_settings()
    if show_locations then
        imgui.Heading('All custom locations')
        imgui.BeginChild('backup_locations',imgui.ImVec2(0,-45),true)
        for _,b in ipairs(locations) do
            imgui.Text(b.name)
            if locations.has_interior(b.name) then imgui.Text(b.name..' Interior') end
            imgui.Separator()
        end
        imgui.EndChild()
        if imgui.AnimButton('Back') then show_locations=false end
        return
    end
    imgui.DrawChild("Backup", function(width)

        imgui.Text("Show active backup requests")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton('##show_active_backups',_config.overlay.display)
        imgui.Separator()
        imgui.Text('Faction backup keybind')
        imgui.SameLine(width-350)
        if imgui.AnimButton('All custom locations') then show_locations=true end
        imgui.SameLine(width-180)
        local keys=shared.hotkey_manager:draw_key_editor('faction_backup',imgui.ImVec2(180,0))
        if keys then _config.bind.keys=keys end
        H.toggle('Mention wanted level','backup_wanted',_config.wanted,width)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    require("src.components.Misc"):render_portable_radio()

    if _config.overlay.display[0] then
        Overlay.render_overlay_settings(_config.overlay, "backup")
    end
end

return Backup

end

package.preload['src.components.Capture'] = function()
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local shared=require('src.shared')
local R=require('src.core.Rules')
local locations=require('src.core.CustomLocations')
local Points=require('src.components.Points')
local C={}
local attendance={name='',flagged=false,next=0}
local last_end={}
local function key(name) return R.trim(name:lower():gsub('^the ','')) end
local warning='!!!!!!POINT IS OVER STOP SHOOTING!!!!!!'

local function check_attendance(name,x,y,z,interior)
    if attendance.name~=name then attendance={name=name,flagged=false} end
    if attendance.flagged then return end
    attendance.interior=interior
    attendance.next=os.clock()+1
    attendance.flagged=locations.find(x,y,z,interior,true)~=nil
end
local function ended(name)
    local k=key(name);local now=os.clock()
    if last_end[k] and now-last_end[k]<5 then return end
    last_end[k]=now
    local point=Points:get_active_point()
    if not point.refresh_timer:is_paused() and key(point.name)==k and doesCharExist(PLAYER_PED) then
        -- A player already inside at the end counts even between samples.
        local x,y,z=getCharCoordinates(PLAYER_PED)
        check_attendance(k,x,y,z,getActiveInterior())
    end
    local flagged=attendance.flagged and attendance.name==k
    if attendance.name==k then attendance={name='',flagged=false} end
    -- Requested for every point end, including players who never attended.
    for i=1,5 do sampAddChatMessage('{FF0000}'..warning,0xFFFF0000) end
    if flagged and not isCharInAnyCar(PLAYER_PED) then
        require('src.ui.Dialogs').show('Leone Menu - Point ended','\n\t{FF0000}'..warning..'\n',0,'OK',nil,true,function() return not isCharInAnyCar(PLAYER_PED) end)
    end
end
function C:register()
    require('src.ui.MainWindow'):add_page('capture',{title='Turfs & Points',icon=fa('MAP'),render_function=function()
        require('src.components.Turfs'):render_ui_settings()
        require('src.components.Points'):render_ui_settings()
        H.position({require('src.components.Turfs'):get_overlay_config()},'capture')
    end})
    shared.event_handler:register('POINT_ENDED',function(name) return {name} end,ended)
    shared.event_handler:register('SERVER_MESSAGE',function(color,text)
        local name=R.strip(text):match('^.- has taken control of the (.-) for .-%.$')
        return name and {name} or false
    end,ended)
    shared.event_handler:register('PED_TICK',function(x,y,z)
        local point=Points:get_active_point()
        if point.name=='' or point.refresh_timer:is_paused() then return false end
        local interior=getActiveInterior()
        local name=key(point.name)
        if attendance.name==name and (attendance.flagged
            or (interior==0 and attendance.interior==0 and os.clock()<attendance.next)) then return false end
        return {name,x,y,z,interior}
    end,check_attendance)
end
return C

end

package.preload['src.components.Equipment'] = function()
-- Blackmarket loadouts use Sputnik's event/hotkey systems and server dialog responses.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local Config=require('src.core.Config')
local H=require('src.ui.Helpers')
local Rules=require('src.core.Rules')
local shared=require('src.shared')
local D=require('src.ui.Dialogs')
local MainWindow=require('src.ui.MainWindow')
local E={}
local MIN_PURCHASE_GAP=250
local cfg={enabled=imgui.new.bool(true),keys={},mode=imgui.new.int(1),delay=imgui.new.int(MIN_PURCHASE_GAP),delay_revision=0}
local file='config/Leone Menu/blackmarket.json'
local names={'Deagle + HP & Vest','Deagle + Sniper + HP & Vest','Deagle + Spas12 + HP & Vest','Deagle + Sniper + Spas12 + HP & Vest'}
local loadouts={{24},{24,34},{24,27},{24,27,34}}
local slots={[24]=2,[27]=3,[34]=6}
local singles={[24]={name='Deagle',guns={24}},[27]={name='SPAS-12',guns={27}},[34]={name='Sniper Rifle',guns={34}}}
local deagle_spas={name='Deagle & SPAS-12',guns={24,27}}
local deagle_sniper={name='Deagle & Sniper',guns={24,34}}
local restore={name='Full health and armor',guns={},restore=true}
local function owns(weapon)
    return getCharWeaponInSlot(PLAYER_PED,slots[weapon]+1)==weapon
end
local function full_health_and_armor()
    local health=getCharHealth(PLAYER_PED)
    if health>=5000000 then health=health-5000000 end
    return health>=100 and getCharArmour(PLAYER_PED)>=100
end
local function next_purchase(sequence)
    local loadout=loadouts[sequence.mode]
    local missing={}
    for _,weapon in ipairs(loadout)do
        if not sequence.bought[weapon] and not owns(weapon)then missing[weapon]=true end
    end
    -- A bundle is valid only when every gun in it is missing right now.
    if missing[24] and missing[27]then return deagle_spas end
    if missing[24] and missing[34]then return deagle_sniper end
    for _,weapon in ipairs(loadout)do if missing[weapon]then return singles[weapon]end end
    if not sequence.bought[restore] and not full_health_and_armor()then return restore end
end
local function fulfilled(purchase)
    for _,weapon in ipairs(purchase.guns)do if not owns(weapon)then return false end end
    return not purchase.restore or full_health_and_armor()
end
local RESPONSE_TIMEOUT=3
local pending
local function stop(reason)
    pending=nil
    if reason then msg(reason)end
end
local function request_dialog(sequence)
    sequence.phase='await_dialog';sequence.dialog_id=nil;sequence.deadline=os.clock()+RESPONSE_TIMEOUT
    samp_send_hidden_command('bm')
end
local function receipt_item(text)
    local plain=Rules.trim(Rules.strip(text)):lower()
    plain=plain:gsub('^[a-z ]+ donator:%s*','')
    local item=plain:match('^you have purchased (.-) for %$[%d,]+%.$')
    return item and (item:gsub('^an? ',''))
end
local function find_item(text,style,wanted)
    local index,line=0,0
    for row in (text..'\n'):gmatch('(.-)\n')do
        if style~=5 or line>0 then
            local plain=Rules.strip(row)
            -- Tabulated dialogs keep the item and price in separate columns.
            local name=Rules.trim((plain:match('^([^\t]*)') or plain):gsub('%$[%d,]+%s*$',''))
            if name:lower()==wanted:lower()then return index end
            index=index+1
        end
        line=line+1
    end
end
local function select_mode(mode)
    local name=names[mode]
    if not name then return msg('USAGE: /bms [1-4]') end
    cfg.mode[0]=mode
    E:save_config()
    local details=name:gsub('HP','Health'):gsub(' ([+&]) ',' {FFFFFF}%1 {33CCFF}')
    -- The default color supplies the prefix without another eight-byte tag.
    -- All four modes fit the SA-MP chat limit of 144 bytes with this label.
    sampAddChatMessage(('[Leone Menu] {FFFFFF}BMS {33CCFF}%d - %s'):format(mode,details),0xFF1E3348)
end
local function begin(mode)
    if pending then return msg('A blackmarket purchase is already running.') end
    local sequence={mode=mode,delay=cfg.delay[0],next_purchase_at=os.clock()+cfg.delay[0]/1000,bought={}}
    if not next_purchase(sequence)then return msg('This loadout is already complete, with full health and armor.')end
    pending=sequence
    request_dialog(sequence)
end
function E:register()
    Config.load(file,cfg)
    cfg.mode[0]=math.max(1,math.min(#names,cfg.mode[0]))
    cfg.delay[0]=math.max(MIN_PURCHASE_GAP,math.min(5000,cfg.delay[0]))
    if cfg.delay_revision==0 then
        if cfg.delay[0]==500 then cfg.delay[0]=MIN_PURCHASE_GAP end
        cfg.delay_revision=1
        E:save_config()
    end
    shared.hotkey_manager:register('blackmarket',cfg.keys,function() if cfg.enabled[0] then begin(cfg.mode[0]) end end)
    sampRegisterChatCommand('bms',function(args)
        args=Rules.trim(args)
        if args~='' then return select_mode(tonumber(args)) end
        D.show('Leone Menu - Blackmarket',table.concat(names,'\n'),2,'OK',function(index) if index>=0 then select_mode(index+1) end end)
    end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        return pending and command:match('^/bm%s*$') and is_command_self_sent('bm')
    end,function() pending=nil end)
    shared.event_handler:register('SERVER_MESSAGE',function()
        return pending and pending.phase=='await_confirmation'
    end,function(_,text)
        if Rules.trim(Rules.strip(text))=="You don't have the cash for this item!" then
            stop()
        elseif receipt_item(text)==pending.purchase.name:lower() then
            pending.confirmed=true
        end
    end)
    shared.event_handler:register('SHOW_DIALOG',function(id,style,title,b1,b2,text)
        if pending then return {id,style,title,text}end
        return false
    end,function(id,style,title,text)
        local sequence=pending
        if Rules.trim(Rules.strip(title))~='Black Market' then
            stop('Another dialog opened; blackmarket purchase stopped.');return
        end
        if style~=2 and style~=4 and style~=5 then
            stop('Blackmarket did not return a purchasable list; purchase stopped.');return
        end
        -- A duplicate/reopened list must not queue the same purchase twice.
        if sequence.phase~='await_dialog' then return false end
        local wanted=next_purchase(sequence)
        if not wanted then pending=nil;sampSendDialogResponse(id,0,0,'');return false end
        if find_item(text,style,wanted.name)==nil then stop('Blackmarket list changed; purchase stopped.');return end
        sequence.phase='selecting';sequence.dialog_id=id
        sequence.deadline=math.max(os.clock(),sequence.next_purchase_at)+RESPONSE_TIMEOUT
        lua_thread.create(function()
            wait(math.max(0,(sequence.next_purchase_at-os.clock())*1000))
            if pending~=sequence or sequence.phase~='selecting' then return end
            -- Re-read just before buying: a gun/vest may have arrived during the wait.
            local purchase=next_purchase(sequence)
            if not purchase then pending=nil;sampSendDialogResponse(id,0,0,'');return end
            local found=find_item(text,style,purchase.name)
            if found==nil then stop('Blackmarket list changed; purchase stopped.');return end
            sequence.phase='await_confirmation';sequence.deadline=os.clock()+RESPONSE_TIMEOUT
            sequence.purchase=purchase
            sequence.confirmed=false
            sequence.next_purchase_at=os.clock()+sequence.delay/1000
            sequence.sending_response=true
            sampSendDialogResponse(id,1,found,'')
            sequence.sending_response=false
            while pending==sequence and not sequence.confirmed and not fulfilled(purchase)do
                if os.clock()>sequence.deadline then
                    stop('Blackmarket purchase was not confirmed; purchase stopped.');return
                end
                wait(50)
            end
            if pending~=sequence then return end
            -- A server receipt can arrive before the client updates its weapon slots.
            for _,weapon in ipairs(purchase.guns)do sequence.bought[weapon]=true end
            if purchase.restore then sequence.bought[restore]=true end
            if next_purchase(sequence) then request_dialog(sequence) else pending=nil end
        end)
        return false
    end)
    shared.event_handler:register('SEND_DIALOG_RESPONSE',function(id)
        return pending and id==pending.dialog_id and not pending.sending_response
    end,function()stop('Blackmarket purchase cancelled.')end)
    shared.event_handler:register('PED_TICK',function()return pending and os.clock()>pending.deadline end,
        function()stop(pending.phase=='await_confirmation' and 'Blackmarket purchase was not confirmed; purchase stopped.' or 'Blackmarket timed out; purchase stopped.')end)
    MainWindow:add_page('blackmarket',{title='Blackmarket',icon=fa('GUN'),render_function=function() E:render_ui_settings() end})
end
function E:save_config() Config.save(file,cfg) end
function E:render_ui_settings()
    imgui.DrawChild('Blackmarket',function(width)
        imgui.Text('Select mode: /bms or /bms [Mode Number]')
        H.toggle('Keybind enabled','bm_enabled',cfg.enabled,width)
        H.bind('Keybind','blackmarket',cfg,width)
        imgui.Separator();imgui.Text('Keybind Modes:')
        for i,name in ipairs(names) do
            if cfg.mode[0]==i then imgui.TextColored(imgui.ImVec4(0,1,0,1),i..'. '..name) else imgui.Text(i..'. '..name) end
        end
        imgui.Separator();imgui.Text('Current Mode');imgui.SameLine(width-160);imgui.SetNextItemWidth(160);imgui.InputInt('##bm_mode',cfg.mode);cfg.mode[0]=math.max(1,math.min(4,cfg.mode[0]))
        imgui.Text('Purchase gap (ms)');imgui.SameLine(width-160);imgui.SetNextItemWidth(160);imgui.InputInt('##bm_delay',cfg.delay);cfg.delay[0]=math.max(MIN_PURCHASE_GAP,math.min(5000,cfg.delay[0]))
    end)
end
return E

end

package.preload['src.components.Extras'] = function()
-- Leone additions mounted in Sputnik's Miscellaneous page.
local imgui=require('upmimgui')
local Config=require('src.core.Config')
local H=require('src.ui.Helpers')
local R=require('src.core.Rules')
local shared=require('src.shared')
local Player=require('src.utils.Player')
local Overlay=require('src.ui.Overlay')
local Frequency=require('src.components.Frequency')
local Parachute=require('src.components.Parachute')
local E={}
local cfg={frisk={keys={}},repair={keys={}},skip=imgui.new.bool(true),auto_freq=imgui.new.bool(false),last_frequency=0}
local file='config/Leone Menu/misc-extras.json'
local state={para_until=0,last_notice=-10,loaded_until=0,initialized=false}
function E:register()
    Config.load(file,cfg)
    -- Legacy nonzero last_frequency was recorded only after a real radio reply.
    if cfg.frequency_known==nil then cfg.frequency_known=cfg.last_frequency~=0 end
    if cfg.frequency_initialized==nil then cfg.frequency_initialized=cfg.frequency_known or cfg.auto_freq[0] end
    Frequency:register(cfg,function()self:save_config()end)
    require('src.components.Vehicles'):register()
    shared.hotkey_manager:register('aim_frisk',cfg.frisk.keys,function()
        local aimed,ped=getCharPlayerIsTargeting(PLAYER_HANDLE)
        if not aimed or not doesCharExist(ped) then return end
        local connected,id=sampGetPlayerIdByCharHandle(ped)
        if connected then sampSendChat('/frisk '..id) end
    end)
    shared.hotkey_manager:register('repair_nearest',cfg.repair.keys,function()
        local ok,id=Player:get_closest_player_id(12,{function(id,ped) return isCharInAnyCar(ped) end})
        if ok then sampSendChat('/repair '..id..' 1') else msg('No nearby driver or passenger found.') end
    end)
    Parachute.new(cfg.skip,function()
        local now=os.clock()
        if now-state.last_notice>=10 then state.para_until=now+3;state.last_notice=now end
    end):register(shared.event_handler)
    sampRegisterChatCommand('skippara',function() cfg.skip[0]=not cfg.skip[0];msg('Skip parachute on scroll has been {1E3348}'..(cfg.skip[0] and 'enabled' or 'disabled')..'{FFFFFF}.') end)
    sampRegisterChatCommand('si',function(args) sampSendChat('/signcheck'..(args~='' and (' '..args) or '')) end)
    local para=Overlay.setup_overlay_defaults(true,0.015,0.43,14,8,1,2,true,{0,0,0,0.75},true,{30/255,51/255,72/255,1})
    local loaded=Overlay.setup_overlay_defaults(true,0.015,0.50,17,10,1,6,true,{0.035,0.045,0.06,0.96},true,{30/255,51/255,72/255,1})
    Overlay.new(para,function() return os.clock()<state.para_until end,function(self) self:TextRGB('{FFFFFF}Parachute\navailable') end)
    Overlay.new(loaded,function() return os.clock()<state.loaded_until end,function(self)
        self:TextRGB('{FFFFFF}Leone Menu')
        imgui.PushFont(nil,13)
        imgui.Text('Version '..require('src.core.Updates').version)
        imgui.PopFont()
    end)
end
function E:loaded()
    lua_thread.create(function()
        while not doesCharExist(PLAYER_PED) or not sampIsLocalPlayerSpawned() or sampGetGamestate()~=3 or sampIsDialogActive() do wait(100) end
        wait(1000);state.initialized=true;Frequency:loaded();state.loaded_until=os.clock()+8
        local ok,stream=pcall(loadAudioStream,getWorkingDirectory()..'/resource/Leone Menu/modloadedin.mp3')
        if ok and stream and stream~=0 then setAudioStreamState(stream,1);wait(15000);releaseAudioStream(stream) end
    end)
end
function E:get_config() return cfg end
function E:save_config() Config.save(file,cfg) end
function E:render_frisk(width) H.bind('Aim and frisk a player','aim_frisk',cfg.frisk,width) end
function E:render_repair(width) H.bind('Offer $1 repair to nearest driver or passenger','repair_nearest',cfg.repair,width) end
function E:render_radio(width) H.toggle('Checks /fmotd for alliance frequency and changes freq','auto_freq',cfg.auto_freq,width,'Reads /stats only on the first manual enable. Remembers the confirmed frequency; listens to startup/manual MOTDs and checks /fmotd every 5 minutes.') end
function E:render_random()
    imgui.DrawChild('Random',function(width)
        imgui.Text('Parachute')
        H.toggle('Skips over parachute but it reappears once you\'re falling - /skippara','skip_para',cfg.skip,width,'Skips the parachute in the direction of your mouse wheel, Q or E, using your existing weapons. Shows parachute availability for 3 seconds with a 10 second cooldown. Selects and keeps the parachute while skydiving.')
        imgui.Text('Shortcuts');imgui.Text('/signcheck -> /si')
    end)
end
function E:render_vehicles()
    imgui.DrawChild('Vehicles',function()
        imgui.Text('Spawn/Despawn vehicle:');imgui.Text('CMD: /vst [Slot Number]');imgui.Separator()
        imgui.Text('Find Vehicle:');imgui.Text('CMD: /fv [Slot Number]');imgui.Separator()
        imgui.Text('Tow vehicle (despawn, then spawn again):');imgui.Text('CMD: /vtow [Slot Number]')
    end)
end
return E

end

package.preload['src.components.Find'] = function()
-- Sputnik's periodic find system, without the removed Wanted/Badge/MDC features.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local Config=require('src.core.Config')
local MainWindow=require('src.ui.MainWindow')
local Player=require('src.utils.Player')
local shared=require('src.shared')
local Timer=require('src.core.Timer')
local H=require('src.ui.Helpers')
local cfg={interval=imgui.new.int(22),looking_after='',hide_redmarker=imgui.new.bool(true)}
local state={enabled=false,id=nil,command='find',has_sent=false}
local timer=Timer.new(cfg.interval)
local RECONNECT_INTERVAL=5
local F={}
local function announce()
    msg(string.format('AutoFind: {6DFB6D}ON{FFFFFF} -> %s (%d) | Level: {6DFB6D}%d{FFFFFF} | Ping: {6DFB6D}%d',cfg.looking_after:gsub('_',' '),state.id,sampGetPlayerScore(state.id),sampGetPlayerPing(state.id)))
end
local function stop()
    state.enabled=false;state.next_lookup=nil;state.resume_at=nil
    msg('AutoFind: {FF0000}OFF')
end
local function send_if_ready()
    if state.resume_at and os.clock()<state.resume_at then return end
    if state.has_sent and not timer:is_ready()then return end
    if Player:is_on_admin_duty()then return end
    timer:trigger();state.has_sent=true;sampSendChat('/'..state.command..' '..state.id)
end
local function wait_for_target(now)
    local text=('Waiting for %s to log back in.'):format(cfg.looking_after:gsub('_',' '))
    if printStringNow then printStringNow(text,2500)
    elseif not state.next_lookup then msg(text) end
    state.next_lookup=now+RECONNECT_INTERVAL
end

local function update_target()
    local now=os.clock()
    if not state.next_lookup and (not sampIsPlayerConnected(state.id)
        or sampGetPlayerNickname(state.id)~=cfg.looking_after) then
        wait_for_target(now)
    end
    if state.next_lookup then
        if now<state.next_lookup then return end
        local id=Player:get_player_id_by_name(cfg.looking_after)
        if not id then return wait_for_target(now) end
        local old_id=state.id
        state.id=id
        state.next_lookup=nil
        state.resume_at=now+RECONNECT_INTERVAL
        local name=cfg.looking_after:gsub('_',' ')
        if id~=old_id then
            msg(('AutoFind: {33CCFF}%s{FFFFFF} -> New ID: {6DFB6D}%d{FFFFFF} | Old ID: {FF0000}%d'):format(name,id,old_id))
        else
            msg(('AutoFind: %s logged back in (ID {6DFB6D}%d{FFFFFF}).'):format(name,id))
        end
    end
    send_if_ready()
end

local function run(command,args)
    args=args:match('^%s*(.-)%s*$')
    if args=='' and state.enabled and state.command==command then stop();return end
    local query=args~='' and args or cfg.looking_after
    if query=='' then return msg('USAGE: /af [Player ID / Name]') end
    local id=Player:resolve_player_id(query);if not id then return end
    local name=sampGetPlayerNickname(id)
    if state.enabled and state.command==command and name==cfg.looking_after then stop();return end
    state.id=id;state.command=command;state.enabled=true;cfg.looking_after=name
    state.next_lookup=nil;state.resume_at=nil
    send_if_ready();announce();Config.save('config/Leone Menu/autofind.json',cfg)
end
function F:register()
    Config.load('config/Leone Menu/autofind.json',cfg);cfg.interval[0]=math.max(15,math.min(140,cfg.interval[0]))
    sampRegisterChatCommand('af',function(args) run('find',args) end)
    sampRegisterChatCommand('afco',function(args) run('cohort',args) end)
    sampRegisterChatCommand('afcho',function(args) run('cohort',args) end)
    shared.event_handler:register('PED_TICK',function()
        return state.enabled and sampIsLocalPlayerSpawned()
    end,update_target)
    shared.event_handler:register('PLAYER_QUIT',function(id)
        return state.enabled and not state.next_lookup and id==state.id
    end,function() wait_for_target(os.clock()) end)
    shared.event_handler:register('PLAYER_JOIN',function(_,_,_,name)
        return state.enabled and state.next_lookup and name==cfg.looking_after
    end,function() state.next_lookup=0 end)
    shared.event_handler:register('SERVER_MESSAGE',function(color,text)
        return state.enabled and (text=='You are unable to find this person.' or text=="You can't find that person as they're hidden in one of their turfs." or text=='You have already searched for someone - wait a little.')
    end,function() timer:set_temp_interval(math.max(state.has_sent and timer:time_remaining()or 0,5));state.has_sent=true end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        local name=command:match('^/(%S+)')
        return name and (name:lower()=='find' or name:lower()=='cohort')
    end,function()timer:trigger();state.has_sent=true end)
    shared.event_handler:register('DISPLAY_GAME_TEXT',function(style,time,text)
        return cfg.hide_redmarker[0] and require('src.core.Rules').strip(text):lower():find('redmarker gone',1,true)~=nil
    end,function() return false end)
    MainWindow:add_page('find',{title='Autofind',icon=fa('LOCATION_DOT'),render_function=function() F:render_ui_settings() end})
end
function F:save_config() Config.save('config/Leone Menu/autofind.json',cfg) end
function F:render_ui_settings()
    imgui.DrawChild('Autofind',function(width)
        imgui.Text('Find Player:');imgui.Text('CMD: /af [Player ID / Name]');imgui.Separator()
        imgui.Text('Cohort Player:');imgui.Text('CMD: /afco [Player ID / Name]')
        imgui.TextWrapped('Note: It will find the player as well as their cohort.');imgui.Separator()
        imgui.Text('Adjust Cooldown:');imgui.Text('Currently (s)');imgui.SameLine();imgui.SetNextItemWidth(160);imgui.InputInt('##find_interval',cfg.interval);cfg.interval[0]=math.max(15,math.min(140,cfg.interval[0]))
        imgui.Separator();imgui.Text('Suggested Cooldown:')
        for i,v in ipairs({125,85,65,35,20}) do imgui.Text('Level '..i..': '..v..'s') end
        imgui.TextWrapped('Note: To prevent lag issues add an extra 4-5 seconds.')
    end)
    imgui.DrawChild('Display##autofind',function(width) H.toggle('Hide Redmarker Message','hide_redmarker',cfg.hide_redmarker,width) end)
end
return F

end

package.preload['src.components.Fixes'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\Fixes.lua

local ffi = require("ffi")
local memory = require("memory")
local vk = require("vkeys")
local shared = require("src.shared")

local function _apply_rendering_fixes()

    memory.write(0x6E1D4F, 2, 1, false)

    memory.write(0x6FB9A0, 0x1C, 1, false)

    memory.write(0x7069F5, 0xEB, 1, false)

    memory.fill(0x70A83B, 0x90, 6, false)

    memory.fill(0x70A4CB, 0x90, 6, false)

    memory.write(0x6E1425, 1, 1, false)

    memory.write(0x884984, 0, 4, false)
end

local function _apply_framerate_fixes()

    memory.write(0x53E94C, 0x00, 1, false)

    memory.write(0xC2B9CC, 0x3EB3B675, 4, false)

    memory.fill(0x524FD7, 0x90, 0x1B, false)

    memory.write(0x736F88, 0, 4, false)
end

local function _apply_general_fixes()

    memory.write(0x745BC9, 0x9090, 2, false)

    memory.write(0x7459E1, 0x9090, 2, false)

    memory.fill(0x6D6517, 0x90, 2, false)
    memory.fill(0x6D0E43, 0x90, 2, false)

    memory.write(0x63F576, 0xEB, 1, false)

    memory.fill(0x460773, 0x90, 7, false)

    memory.copy(0x4EB9A0, memory.strptr('\xC2\x04\x00'), 3, true)

    memory.write(sampGetBase() + 0x2D3C45, 0, 2, true)
end

local function _preload_animations()
    ffi.cdef [[
        typedef void (__cdecl *AddAnimBlockRef_t)(int index);
    ]]

    local AddAnimBlockRef = ffi.cast("AddAnimBlockRef_t", 0x4D3FB0)
    local animBlocksIdStart = memory.read(0x48C36B + 2, 4, true)
    local ms_numAnimBlocks = memory.read(0xB4EA30, 4, true)

    for id = 1, ms_numAnimBlocks - 1 do
        local modelId = animBlocksIdStart + id
        requestModel(modelId)
        AddAnimBlockRef(id)
    end

    loadAllModelsNow()
end

local function _register_event_handlers()

    shared.event_handler:register(
        "PED_TICK_IN_CAR",
        function(x, y, z, vehicle_handle, is_driver)
            if is_driver then
                return { vehicle_handle }
            end
            return false
        end,
        function(vehicle_handle)

            if isKeyJustPressed(vk.VK_H) and not is_cursor_active() then
                switchCarSiren(vehicle_handle, not isCarSirenOn(vehicle_handle))
            end
        end
    )
end

local Fixes = {}

function Fixes:register()
    _apply_rendering_fixes()
    _apply_framerate_fixes()
    _apply_general_fixes()

    _preload_animations()
    _register_event_handlers()
end

return Fixes

end

package.preload['src.components.Frequency'] = function()
-- One /stats read on the first manual enable, then persisted frequency + MOTDs.
local R=require('src.core.Rules')
local shared=require('src.shared')
local F={}
local cfg,save
local s
local function ready()
    return F.initialized and doesCharExist(PLAYER_PED) and sampIsLocalPlayerSpawned()
        and sampGetGamestate()==3 and not sampIsDialogActive() and not isPauseMenuActive()
end
local function remember(n)
    cfg.last_frequency=n;cfg.frequency_known=true;s.current=n
    save()
end
local function request_motd()
    s.motd_until=os.clock()+6;s.next_motd=os.clock()+300
    samp_send_hidden_command('fmotd')
end
local function first_read()
    cfg.frequency_initialized=true;save()
    s.stats_until=os.clock()+6;s.stats_capture_until=s.stats_until;s.stats_header=false
    print('[Frequency] First manual enable: requesting /stats once.')
    samp_send_hidden_command('stats')
end
function F:loaded()
    self.initialized=true
    s.next_motd=os.clock()+300
end
function F:tick()
    local now=os.clock()
    local enabled=cfg.auto_freq[0]
    if enabled~=s.enabled then
        s.enabled=enabled
        if enabled then
            if not cfg.frequency_initialized then s.first_read_pending=true
            elseif not s.desired_at or now-s.desired_at>300 then s.next_motd=now end
            s.need_apply=true
        else
            s.first_read_pending=false;s.stats_until=0;s.stats_capture_until=0
            s.motd_until=0;s.pending=nil;s.need_apply=false
        end
    end
    if not enabled then return end
    if s.stats_until>0 and now>s.stats_until then
        s.stats_until=0;s.stats_capture_until=0
        -- Continue using a known/confirmed frequency and the MOTD, never /stats again.
        print('[Frequency] First-enable /stats reply was not received; waiting for alliance MOTD.')
        s.need_apply=true
        if not s.desired_at or now-s.desired_at>300 then s.next_motd=now end
    end
    if s.pending and now>s.set_until then s.pending=nil end
    if not ready() then return end
    if s.first_read_pending then s.first_read_pending=false;first_read();return end
    if s.stats_until>0 then return end
    if now>=s.next_motd then request_motd()end
    if s.need_apply and s.desired~=nil then
        s.need_apply=false
        if s.current~=s.desired and s.pending~=s.desired then
            s.pending=s.desired;s.set_until=now+8
            sampSendChat('/setfreq '..s.desired)
        end
    end
end
function F:register(settings,on_save)
    cfg=settings;save=on_save
    s={enabled=cfg.auto_freq[0],current=cfg.frequency_known and cfg.last_frequency or nil,
       next_motd=os.clock()+300,motd_until=0,stats_until=0,stats_capture_until=0}
    self.initialized=false
    shared.event_handler:register('SERVER_MESSAGE',function(color,text)return {color,text}end,function(color,text)
        local plain=R.strip(text);local now=os.clock()
        local confirmed=tonumber(plain:match('^You have set the frequency of your portable radio to (%-?%d+) kHz%.$'))
        if confirmed then
            local automatic=s.pending==confirmed
            remember(confirmed)
            if automatic then s.pending=nil;msg('Freq has changed to {1E3348}'..confirmed);return false end
            return
        end
        local radio=plain:match('Radio:%s*(%-?%d+)')
        if cfg.auto_freq[0] and s.stats_until>0 and radio then
            remember(tonumber(radio));s.stats_until=0;s.need_apply=true
            if not s.desired_at or now-s.desired_at>300 then s.next_motd=now+0.5 end
            return false
        end
        if cfg.auto_freq[0] and (s.stats_capture_until or 0)>now and
            (plain:match('^_+$') or plain:find('(Level:',1,true) or plain:find('(Family:',1,true) or
             plain:find('(Total wealth:',1,true) or plain:find('(Respect points:',1,true) or
             plain:find('(Crimes:',1,true) or plain:find('(Rope:',1,true))then
            if plain:match('^_+$')then
                if s.stats_header then s.stats_capture_until=0 else s.stats_header=true end
            end
            return false
        end
        local freq=R.frequency(plain)
        if freq then
            s.desired=freq;s.desired_at=now;s.need_apply=true
            if cfg.auto_freq[0]then
                s.next_motd=now+300
                if now<s.motd_until then s.motd_until=0;return false end
            end
        end
    end)
    -- A manual /fmotd reply stays visible even if an automatic request is pending.
    shared.event_handler:register('SEND_COMMAND',function(command)
        return R.trim(command):lower()=='/fmotd' and is_command_self_sent('fmotd')
    end,function()s.motd_until=0 end)
    shared.event_handler:register('PED_TICK',function()return true end,function()self:tick()end)
end
return F

end

package.preload['src.components.Home'] = function()
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local U=require('src.core.Updates')
local MainWindow=require('src.ui.MainWindow')
local Home={reload_requested=false}
function Home:register()
    MainWindow:add_page('home',{title='Home',icon=fa('HOUSE'),order=0,render_function=function()
        imgui.Heading('Leone Menu')
        imgui.Text('Version '..U.version)
        imgui.DrawChild('Credits',function()
            imgui.TextWrapped('Built on Sputnik, created by Kev and Futurestunt. Thank you for the original menu and its systems.')
            if imgui.AnimButton('Kev - forum profile') then H.open('https://forums.hzgaming.net/member.php/49614-Kev') end
            if imgui.AnimButton('Sputnik - original forum thread') then H.open('https://forums.hzgaming.net/showthread.php/639069-sputnik-the-non-shady-alternative-to-PEMENU') end
            imgui.Separator()
            imgui.Text('Leone Menu by Garry')
            if imgui.AnimButton('Garry - forum profile') then H.open('https://forums.hzgaming.net/member.php/25596-Garry') end
            if imgui.AnimButton('Discord: garries - click to copy') then setClipboardText('garries');msg('Discord username copied: {1E3348}garries{FFFFFF}.') end
        end)
        if imgui.AnimButton(fa('ROTATE')..' Reload Leone Menu') then
            Home.reload_requested=true
        end
        imgui.SameLine()
        if imgui.AnimButton('Check for updates') then U.check_menu(true);U.check_skins(true) end
        imgui.TextWrapped(U.status)
        imgui.TextWrapped(U.skins_status)
    end})
    MainWindow:select_page('home')
end
return Home

end

package.preload['src.components.Keybinds'] = function()
-- Retains Sputnik's shared hotkey editor and execution manager.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local Config=require('src.core.Config')
local MainWindow=require('src.ui.MainWindow')
local shared=require('src.shared')
local H=require('src.ui.Helpers')
local K={}
local cfg={binds={},next_id=1}
local file='config/Leone Menu/keybinds.json'
local draft={command='',keys={}}
local function register(b)
    local ok=shared.hotkey_manager:register('custom_'..b.id,b.keys,function() if b.enabled[0] then send_user_command(b.command) end end)
    if not ok then b.keys={};shared.hotkey_manager:register('custom_'..b.id,{},function() if b.enabled[0] then send_user_command(b.command) end end) end
end
function K:register()
    Config.load(file,cfg)
    for _,b in ipairs(cfg.binds) do
        local saved=b.enabled;b.enabled=imgui.new.bool(type(saved)=='table' and saved.__array and saved.__array[1]~=false or saved==true)
        b.keys=b.keys or {};register(b);cfg.next_id=math.max(cfg.next_id,b.id+1)
    end
    shared.hotkey_manager:register('custom_draft',{},function() end)
    MainWindow:add_page('keybinds',{title='Keybinds',icon=fa('KEYBOARD'),render_function=function() K:render_ui_settings() end})
end
function K:save_config() Config.save(file,cfg) end
function K:render_ui_settings()
    imgui.Text('Keybinds:')
    local area=imgui.GetContentRegionAvail()
    imgui.BeginChild('custom_binds',imgui.ImVec2(0,math.max(120,area.y-48)),true)
    for i,b in ipairs(cfg.binds) do
        imgui.PushID(b.id)
        local width=imgui.GetContentRegionAvail().x
        imgui.Text(b.command);imgui.SameLine(width-205-imgui.ToggleButtonWidth()-10)
        imgui.ToggleButton('##enabled',b.enabled);imgui.SameLine(width-205)
        local keys=shared.hotkey_manager:draw_key_editor('custom_'..b.id,imgui.ImVec2(155,0));if keys then b.keys=keys end
        imgui.SameLine(width-40)
        if imgui.AnimButton(fa('TRASH')) then shared.hotkey_manager:unregister('custom_'..b.id);table.remove(cfg.binds,i);self:save_config() end
        imgui.PopID()
    end
    imgui.EndChild()
    if imgui.AnimButton('Add') then draft.command='';draft.keys={};shared.hotkey_manager.registered.custom_draft.keys={};imgui.OpenPopup('Add Keybind') end
    if imgui.BeginPopupModal('Add Keybind',nil,imgui.WindowFlags.AlwaysAutoResize) then
        draft.command=H.input('##custom_command',draft.command,'/dance 1',350,128)
        local keys=shared.hotkey_manager:draw_key_editor('custom_draft',imgui.ImVec2(180,0));if keys then draft.keys=keys end
        if imgui.AnimButton('Save') then
            if not draft.command:match('^/%S+') or draft.command:find('[\r\n]') or #draft.keys==0 then msg('Enter a command beginning with / and choose a keybind.')
            else
                shared.hotkey_manager.registered.custom_draft.keys={}
                local b={id=cfg.next_id,command=draft.command,keys=draft.keys,enabled=imgui.new.bool(true)}
                cfg.next_id=cfg.next_id+1;cfg.binds[#cfg.binds+1]=b;register(b);self:save_config();imgui.CloseCurrentPopup()
            end
        end
        imgui.SameLine();if imgui.AnimButton('Cancel') then shared.hotkey_manager.registered.custom_draft.keys={};imgui.CloseCurrentPopup() end
        imgui.EndPopup()
    end
end
return K

end

package.preload['src.components.Misc'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\Misc.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local keys = require("game.keys")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local SPRUNK_WAIT_TIME = 0.050
local SPECIAL_ACTION_DRINK_SPRUNK = 23

local CONFIG_PATH = "config/Leone Menu/miscellaneous.json"

local default_data = {
    font = {
        path = ""
    },
    auto_eject = {
        enabled = imgui.new.bool(true),
    },
    auto_accept_repair = {
        enabled = imgui.new.bool(true),
    },
    auto_pick_lock = {
        enabled = imgui.new.bool(true),
    },
    beacon_resolver = {
        enabled = imgui.new.bool(true),
    },
    portable_radio = {
        show_frequency = imgui.new.bool(true),
    },
    sprunk_spam = {
        enabled = imgui.new.bool(true),
    },
    sniper_frisk_sound = {
        enabled = imgui.new.bool(true),
    },
}

local _config = default_data

local _auto_eject_state = {
    timer = Timer.new(imgui.new.int(5)),
}

local _portable_radio = {
    current_frequency = 0,
}

local _sprunk_spam_state = {
    last = os.clock(),
}

local _vehicle_storage_state = {
    selected_slot = 0,
    selected_car = "",
}

local fonts = {
    list = {},
    selected = imgui.new.int(0),
}

local function get_system_fonts()
    local dirs = {
        getFolderPath(0x14),
        os.getenv('LOCALAPPDATA') .. '\\Microsoft\\Windows\\Fonts'
    }
    local exts = { '*.ttf', '*.otf' }
    local found = {}

    for _, dir in ipairs(dirs) do
        if dir then
            for _, ext in ipairs(exts) do
                local search, file = findFirstFile(dir .. '\\' .. ext)
                if search then
                    while file do
                        local full_path = dir .. '\\' .. file
                        table.insert(found, full_path)

                        file = findNextFile(search)
                    end
                    findClose(search)
                end
            end
        end
    end
    return found
end

local function _force_recon(delay)
    delay = delay or 0

    sampSetGamestate(5)

    local bs = raknetNewBitStream()
    raknetEmulRpcReceiveBitStream(40, bs)
    raknetDeleteBitStream(bs)

    if sampIsDialogActive() then
        sampCloseCurrentDialogWithButton(0)
    end

    lua_thread.create(function()
        wait(delay * 1000)
        sampSetGamestate(1)
    end)
end

local function resolve_beacons_in_text(text, color)
    if not _config.beacon_resolver.enabled[0] then
        return text
    end

    local function to_rp_name(nickname)
        return nickname:gsub("_", " ")
    end

    text = text:gsub("(%f[%w])([Bb])(%d+)%f[%W]", function(_, org_b, id)
        local player_id = tonumber(id)
        if player_id and sampIsPlayerConnected(player_id) then
            local player_name = sampGetPlayerNickname(player_id)
            local player_color = bit.band(sampGetPlayerColor(player_id), 0xFFFFFF)

            return string.format("%s%d {{%06x}%s%s}", org_b, player_id, player_color,
                to_rp_name(player_name), color)
        end

        return org_b .. id
    end)

    return text
end

local function _register_event_handlers()

    shared.event_handler:register(
        "PED_TICK_IN_CAR",
        function(x, y, z, vehicle_handle, is_driver)
            if _config.auto_eject.enabled[0] and is_driver then
                return { vehicle_handle }
            end
            return false
        end,
        function(vehicle_handle)
            if getCarHealth(vehicle_handle) <= 250.0 then
                if _auto_eject_state.timer:is_ready() then
                    _auto_eject_state.timer:trigger()
                    local players_in_vehicle = {}

                    for target_player_id = 0, sampGetMaxPlayerId(true) do
                        if sampIsPlayerConnected(target_player_id) then
                            local ok, target_ped = sampGetCharHandleBySampPlayerId(target_player_id)
                            if ok and doesCharExist(target_ped) and isCharInCar(target_ped, vehicle_handle) then
                                table.insert(players_in_vehicle, target_player_id)
                            end
                        end
                    end

                    if #players_in_vehicle > 0 then
                        shared.notification:show("Ejecting players from the burning vehicle...",
                            shared.notification.types.INFO)

                        lua_thread.create(function()
                            for _, target_player_id in ipairs(players_in_vehicle) do
                                sampSendChat("/eject " .. target_player_id)
                                wait(750)
                            end
                        end)
                    end
                end
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.LIGHTBLUE and _config.auto_accept_repair.enabled[0] then
                local match = text:match(
                    "^%* Car Mechanic .- wants to repair your car for %$1, %(type %/accept repair%) to accept%.$")
                if match then
                    return true
                end
            end
            return false
        end,
        function()
            if isCharInAnyCar(PLAYER_PED) then
                sampSendChat("/accept repair")
            end
            return false
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE and _config.auto_pick_lock.enabled[0] and text == "You have failed to pick the lock!" then
                return true
            end
            return false
        end,
        function()
            sampSendChat("/picklock")
        end
    )

    shared.event_handler:register(
        "PED_TICK_ON_FOOT",
        function(x, y, z)
            if _config.sprunk_spam.enabled[0] and (getCharHealth(PLAYER_PED) - 5000000) ~= 100.0 then
                local my_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))

                if sampGetPlayerSpecialAction(my_id) == SPECIAL_ACTION_DRINK_SPRUNK then
                    return true
                end
            end
            return false
        end,
        function()
            if os.clock() - _sprunk_spam_state.last >= SPRUNK_WAIT_TIME then
                setGameKeyState(keys.player.FIREWEAPON, 255)
                _sprunk_spam_state.last = os.clock()
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.GRAD1 and _config.sniper_frisk_sound.enabled[0] and text == "Weapon: Sniper Rifle." then
                return true
            end
            return false
        end,
        function()
            clearMissionAudio(1)
            loadMissionAudio(1, 5205)
            playMissionAudio(1)
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if _config.beacon_resolver.enabled[0] then
                return { color, text }
            end

            return false
        end,
        function(color, text)

            local last_hex_color
            for hex_color in text:gmatch("{%x%x%x%x%x%x}") do
                last_hex_color = hex_color
            end
            local normal_color = last_hex_color or string.format("{%06X}", bit.rshift(color, 8))

            text = resolve_beacons_in_text(text, normal_color)

            return { color, text }
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.FREQUENCY then
                local frequency, player_name, content = text:match("^%*%* Radio %((%-?%d+) kHz%) %*%* (.-): (.+)$")
                if frequency and player_name and content then
                    return { color, tonumber(frequency), player_name, content }
                end
            end
            return false
        end,
        function(color, frequency, player_name, content)
            local raw_name = player_name:gsub(" ", "_")
            local player_id = Player:get_player_id_by_name(raw_name)

            local show_frequency=_config.portable_radio.show_frequency[0]
            if not player_id then
                if not show_frequency then return {color,'** Radio ** '..player_name..': '..content} end
                return
            end

            local player_color = bit.band(sampGetPlayerColor(player_id), 0xFFFFFF)
            local prefix=show_frequency and ('** Radio (%d kHz) ** '):format(frequency) or '** Radio ** '
            local text=prefix..string.format("{%06X}%s (%d){FFFFFF}: {6DFB6D}%s", player_color, player_name, player_id, content)

            local last_hex_color
            for hex_color in text:gmatch("{%x%x%x%x%x%x}") do
                last_hex_color = hex_color
            end
            local normal_color = last_hex_color or string.format("{%06X}", bit.rshift(color, 8))

            text = resolve_beacons_in_text(text, normal_color)

            return { color, text }
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local frequency = text:match("^You have set the frequency of your portable radio to (%-?%d+) kHz%.$")
                if frequency then
                    return { tonumber(frequency) }
                end
            end
            return false
        end,
        function(frequency)
            if frequency == _portable_radio.current_frequency then
                return
            end

            _portable_radio.current_frequency = frequency
        end
    )


end

local function _register_commands()

    sampRegisterChatCommand(
        "recon",
        function(args)
            local delay = tonumber(args) or 0

            _force_recon(delay)

            local msg_text = delay == 0 and "Reconnecting..." or
                "Reconnecting in " .. delay .. " second" .. (delay == 1 and "..." or "s...")
            msg(msg_text)
        end
    )

    sampRegisterChatCommand(
        "nick",
        function(args)
            if args == "" then
                return msg('Usage: /nick <name>')
            end

            if not Player:is_valid_samp_name(args) then
                return msg("You have entered an invalid roleplay name.")
            end

            sampSetLocalPlayerName(args)
            _force_recon(0)
            msg("Reconnecting with the name '" .. args .. "'.")
        end
    )

    sampRegisterChatCommand(
        "leone",
        function(args)
            if args == "cmds" then
                local visible_cmds = {}
                for cmd, _ in pairs(get_registered_commands()) do
                    table.insert(visible_cmds, cmd)
                end

                table.sort(visible_cmds)
                msg("{BE60F7}" .. #visible_cmds .. " registered commands{FFFFFF}:")

                local line = {}
                for i, cmd in ipairs(visible_cmds) do
                    table.insert(line, cmd)
                    if #line == 6 then
                        msg(table.concat(line, ", "))
                        line = {}
                    end
                end

                if #line > 0 then
                    msg(table.concat(line, ", "))
                end
            else
                if MainWindow:is_open() then
                    MainWindow:hide()
                else
                    MainWindow:show()
                end
            end
        end
    )
end

local Misc = {}

function Misc:register()
    carboneum.load(CONFIG_PATH, _config)
    _config.portable_radio.import_url = nil

    fonts.list = get_system_fonts()
    for i, font_path in ipairs(fonts.list) do
        if font_path == _config.font.path then
            fonts.selected[0] = i - 1
        end
    end

    _register_event_handlers()
    _register_commands()

    MainWindow:add_page("miscellaneous", {
        icon = fa("ELLIPSIS"),
        title = "Miscellaneous",
        icon_box_color = imgui.ImVec4(0.6, 0.6, 0.6, 1),
        render_function = Misc.render_ui_settings
    })
end

function Misc:get_config()
    return _config
end

function Misc:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function Misc:render_portable_radio()
    imgui.DrawChild("Portable Radio", function(width)

        imgui.Text("Show frequency in chat messages")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        if imgui.ToggleButton("##show_frequency", _config.portable_radio.show_frequency) then
            Misc:save_config()
        end
        require("src.components.Extras"):render_radio(width)
    end)
end

function Misc:render_ui_settings()

    imgui.DrawChild("Font Selector", function(width)
        imgui.Text("Change font for on-screen elements")

        imgui.SameLine(width - 200)
        local current_font_name = (fonts.list[fonts.selected[0] + 1] or _config.font.path):match("[^\\]+$") or "Default"
        imgui.SetNextItemWidth(200)
        if imgui.BeginCombo("##font_selector", current_font_name) then
            for i, font_path in ipairs(fonts.list) do
                local name = font_path:match("[^\\]+$") or font_path
                local is_selected = (fonts.selected[0] == i - 1)

                if imgui.Selectable(name, is_selected) then
                    fonts.selected[0] = i - 1

                    local font_config = imgui.ImFontConfig()
                    imgui.GetIO().FontDefault = imgui.GetIO().Fonts:AddFontFromFileTTF(font_path, 18.0, font_config)

                    local icon_config = imgui.ImFontConfig()
                    icon_config.MergeMode = true
                    icon_config.GlyphMinAdvanceX = 16.0
                    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 16.0,
                        icon_config)
                end

                if is_selected then imgui.SetItemDefaultFocus() end
            end
            imgui.EndCombo()
        end

        imgui.SameLine(width - 200 - 50 - 10)
        if imgui.AnimButton(fa("FLOPPY_DISK"), imgui.ImVec2(50, 0)) then
            local selected_path = fonts.list[fonts.selected[0] + 1]
            if selected_path then
                _config.font.path = selected_path
            end
        end
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Automatization", function(width)

        imgui.Text("Automatically eject all players from vehicle when it catches fire")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_eject", _config.auto_eject.enabled)

        imgui.Separator()

        imgui.Text("Automatically accept $1 repair offers from players")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_accept_repair", _config.auto_accept_repair.enabled)
        require("src.components.Extras"):render_repair(width)

        imgui.Separator()

        imgui.Text("Automatically retry picking a vehicle lock after a failed attempt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##auto_pick_lock", _config.auto_pick_lock.enabled)

        imgui.Separator()

        imgui.Text("Spam LMB while holding a Sprunk can to quickly recover health")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##sprunk_spam", _config.sprunk_spam.enabled)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Beacon Resolver", function(width)
        imgui.Text('Resolve player IDs when written as "B20" to their actual name instead')
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##beacon_resolver", _config.beacon_resolver.enabled)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Frisking", function(width)
        imgui.Text("Play sound when frisking a player who has a sniper rifle")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##sniper_frisk_sound", _config.sniper_frisk_sound.enabled)
        require("src.components.Extras"):render_frisk(width)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    require("src.components.Extras"):render_random()
    require("src.components.Extras"):render_vehicles()
end

return Misc

end

package.preload['src.components.Parachute'] = function()
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

end

package.preload['src.components.PedCounter'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\PedCounter.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")

local CONFIG_PATH = "config/Leone Menu/pedcounter.json"

local default_data = {
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.999,
        0.978,
        15,
        5,
        0,
        1,
        true,
        { 0, 0, 0, 0.588 },
        false,
        { 0, 0, 0, 0.588 }
    ),
}
default_data.overlay.display_outside_interiors = imgui.new.bool(true)

local _config = default_data

local PedCounter = {}

function PedCounter:get_active_slots()
    return sampGetPlayerCount(true) - 1
end

function PedCounter:register()
    carboneum.load(CONFIG_PATH, _config)

    MainWindow:add_page("ped_counter", {
        icon = fa("PERSON_WALKING"),
        title = "Ped Counter",
        icon_box_color = imgui.ImVec4(0.2, 0.7, 0.5, 1),
        render_function = PedCounter.render_ui_settings
    })
end

function PedCounter:get_config()
    return _config
end

function PedCounter:get_overlay_config()
    return _config.overlay
end

function PedCounter:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function PedCounter:render_ui_settings()
    imgui.DrawChild("Ped Counter", function(width)
        imgui.Text("Show overlay with active ped slot count")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##active_ped_slots", _config.overlay.display)

        if _config.overlay.display[0] then
            imgui.Separator()

            imgui.Text("Enable overlay outside interiors")
            imgui.SameLine(width - imgui.ToggleButtonWidth())
            imgui.ToggleButton("##ped_counter_outside_interiors", _config.overlay.display_outside_interiors)
        end
    end)

    if _config.overlay.display[0] then
        Overlay.render_overlay_settings(_config.overlay, "ped_counter")
    end
end

return PedCounter

end

package.preload['src.components.Phone'] = function()
-- Sputnik phonebook lookup, with a scoped request and the requested SMS UI.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local bit=require('bit')
local Colors=require('src.core.Colors')
local Config=require('src.core.Config')
local H=require('src.ui.Helpers')
local Player=require('src.utils.Player')
local R=require('src.core.Rules')
local shared=require('src.shared')
local P={}
local cfg={show_id=imgui.new.bool(true),colorize=imgui.new.bool(true),hide_extra=imgui.new.bool(true)}
local pending
local last_sms_at=-math.huge
local function normalized(name) return name:lower():gsub(" ","_") end
local function bad_player() msg("Player isn't logged in or ID/name is wrong, try again") end
function P:register()
    Config.load('config/Leone Menu/phone.json',cfg)
    sampRegisterChatCommand('pm',function(args)
        local recipient,message=args:match('^(%S+)%s+(.+)$')
        if not recipient then return msg('USAGE: /pm [Player ID / Name] [Message]') end
        if pending then return msg('Please wait for the current phone lookup.') end
        local id=Player:resolve_player_id(recipient);if not id then return end
        pending={id=id,name=sampGetPlayerNickname(id),message=message,deadline=os.clock()+6}
        samp_send_hidden_command('number',tostring(id))
    end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        return command:lower():match('^/sms%s+%-?%d+%s+%S')~=nil
    end,function() last_sms_at=os.clock() end)
    shared.event_handler:register('SERVER_MESSAGE',function(color,text) return {color,text} end,function(color,text)
        local plain=R.strip(text)
        if pending then
            local p=pending
            local name,number=plain:match('^%* (.-) %((%-?%d+)%)$')
            if name and name:gsub(' ','_')==p.name then
                pending=nil
                if sampIsPlayerConnected(p.id) and sampGetPlayerNickname(p.id)==p.name then
                    last_sms_at=os.clock()
                    sampSendChat('/sms '..number..' '..p.message)
                else bad_player() end
                return false
            elseif plain=='Invalid player specified.' then pending=nil;bad_player();return false
            elseif plain:match('^%* You cannot find .- in the phonebook!$') then
                local who=plain:match('^%* You cannot find (.-) in the phonebook!$')
                if who:gsub(' ','_')==p.name then pending=nil;msg(string.format("%s ({1E3348}%d{FFFFFF}) doesn't own a phone",who,p.id));return false end
            end
        end
        if cfg.hide_extra[0] then
            if color==Colors.WHITE and plain=='Text message delivered.' then return false end
            local actor=plain:match('^%* (.+) takes out a cellphone%.$')
            if actor and os.clock()-last_sms_at<=2 then
                local ok,local_id=sampGetPlayerIdByCharHandle(PLAYER_PED)
                local own_name=ok and sampGetPlayerNickname(local_id)
                if own_name and normalized(actor)==normalized(own_name) then return false end
            end
        end
        if color~=Colors.YELLOW and color~=Colors.YELLOW2 then return end
        if not cfg.show_id[0] and not cfg.colorize[0] then return end
        local message,name,number=plain:match('^SMS: (.+), Sender: (.-) %((%-?%d+)%)$')
        if not message or (name=='MOLE' and number=='555') or name:find('[automated response]',1,true) then return end
        local id=Player:get_player_id_by_name(name:gsub(' ','_'))
        if not id or id<0 then return end

        local sender=name..' ('..number..')'
        local suffix=cfg.show_id[0] and (' [%d]'):format(id) or ''
        local add_id=suffix~='' and #plain+#suffix<=128
        local text_color=string.format('{%06X}',bit.rshift(color,8))
        local player_color=sampGetPlayerColor(id)
        local rgb=bit.band(player_color,0xFFFFFF)
        local add_color=cfg.colorize[0] and rgb~=0xFFFFFF and rgb~=0xFCFCFC
            and #plain+(add_id and #suffix or 0)+8<=128
        if not add_id and not add_color then return end
        if add_color then
            local tag=bit.tobit(player_color)==bit.tobit(0xAAFFF000) and '{FFD800}' or ('{%06X}'):format(rgb)
            sender=tag..sender
        end
        if add_id then sender=sender..' '..text_color..suffix:sub(2) end
        return {color,('SMS: %s, Sender: %s'):format(message,sender)}
    end)
    shared.event_handler:register('PED_TICK',function() return pending and os.clock()>pending.deadline end,function() pending=nil;msg('Phone lookup timed out. Please try again.') end)
    shared.event_handler:register('PLAYER_QUIT',function(id) return pending and pending.id==id end,function() pending=nil;bad_player() end)
    require('src.ui.MainWindow'):add_page('phone',{title='Phone',icon=fa('MOBILE_SCREEN_BUTTON'),order=999,render_function=function() P:render_ui_settings() end})
end
function P:save_config() Config.save('config/Leone Menu/phone.json',cfg) end
function P:render_ui_settings()
    imgui.DrawChild('Phone',function(width)
        H.toggle('Show Player ID','sms_id',cfg.show_id,width)
        H.toggle('Colorize Name','sms_color',cfg.colorize,width)
        H.toggle('Hide Extra Lines','sms_extra',cfg.hide_extra,width,'Removes cellphone emotes, text message delivered and other extra phone lines from chat.')
    end)
    imgui.DrawChild('SMS Players',function()
        imgui.Text('CMD: /pm [Player ID / Name] [Message]')
        imgui.TextWrapped("You can use part of the player's name. If several players match, the menu lists their names and IDs before sending anything.")
    end)
end
return P

end

package.preload['src.components.Points'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\Points.lua

local bit = require("bit")
local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local CONFIG_PATH = "config/Leone Menu/points.json"

local default_data = {
    auto_capture = imgui.new.bool(false),
    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.375,
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
default_data.overlay.display_next_information = imgui.new.bool(true)

local _config = default_data

local _points = {}

local _active_point_war = {
    refresh_timer = Timer.new(imgui.new.int(45)),

    name = "",
    captured_by = "",
    time_left = 0,
}

local _last_nearby_point = {
    name = "",
    position = {
        x = 0.0,
        y = 0.0,
        z = 0.0,
    },
}

local function _detect_point(text, color, is_argb)

    local rgba_color = color
    if is_argb then
        local a = bit.band(bit.rshift(color, 24), 0xFF)
        local r = bit.band(bit.rshift(color, 16), 0xFF)
        local g = bit.band(bit.rshift(color, 8), 0xFF)
        local b = bit.band(color, 0xFF)
        rgba_color = bit.bor(bit.lshift(r, 24), bit.lshift(g, 16), bit.lshift(b, 8), a)
    end

    if rgba_color ~= Colors.YELLOW2 then
        return nil
    end

    local point = text:match("^(.-)\nOwner%: .-$")
    if not point then
        return nil
    end

    return point
end

local function _search_point_3d_text()
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            local text, color, pos_x, pos_y, pos_z, distance, ignoreWalls, player, vehicle = sampGet3dTextInfoById(id)
            local point = _detect_point(text, color, true)
            if point then
                _last_nearby_point.name = point
                _last_nearby_point.position.x = pos_x
                _last_nearby_point.position.y = pos_y
                _last_nearby_point.position.z = pos_z
            end
        end
    end
end

local function _end_point_war()
    if _active_point_war.name ~= "" then shared.event_handler:process("POINT_ENDED", _active_point_war.name) end
    _active_point_war.refresh_timer:pause()

    _active_point_war.name = ""
    _active_point_war.captured_by = ""
    _active_point_war.time_left = 0
end

local function _start_point_war(name, captured_by, time_left)
    _active_point_war.refresh_timer:resume()

    _active_point_war.name = name
    _active_point_war.captured_by = captured_by
    _active_point_war.time_left = time_left
end

local function _register_event_handlers()

    shared.event_handler:register(
        "CREATE_3D_TEXT",
        function(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
            local point = _detect_point(text, color, false)
            if point then
                return { point, position }
            end

            return false
        end,
        function(point, position)
            _last_nearby_point.name = point
            _last_nearby_point.position.x = position.x
            _last_nearby_point.position.y = position.y
            _last_nearby_point.position.z = position.z
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text:match("^Welcome to Horizon Roleplay, .-%.$")
        end,
        function()
            samp_send_hidden_command("points")
        end
    )

    shared.event_handler:register(
        "SHOW_DIALOG",
        function(id, style, title, button1, button2, text)
            if title == "{FFA500}Horizon Roleplay Points" then
                return { text }
            end
            return false
        end,
        function(text)
            local fetched_points = {}
            for name, owner, hours in text:gmatch("{FFA500}Name:{FFFFFF} (.-) {FFA500}| {FFA500}Owner:(.-) {FFA500}| {FFA500}Captured By:{FFFFFF} .- {FFA500}| {FFA500}Hours:{FFFFFF} (%d+)") do
                owner = owner:gsub("%s+", "", 1)

                table.insert(fetched_points, { name = name, owner = owner, hours = tonumber(hours) })
            end

            for _, fetched_point in ipairs(fetched_points) do
                if not _points[fetched_point.name] then
                    _points[fetched_point.name] = fetched_point
                else
                    _points[fetched_point.name].owner = fetched_point.owner
                    _points[fetched_point.name].hours = fetched_point.hours
                end

                if fetched_point.hours == 0 and _active_point_war.refresh_timer:is_paused() then
                    samp_send_hidden_command("pointinfo")
                end
            end

            return is_command_self_sent("points")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW and _config.auto_capture[0] and not Player:is_on_admin_duty() then
                local point_name = text:match("^(.-) has become available for capture%.$")
                if point_name then
                    return { point_name }
                end
            end
            return false
        end,
        function(point_name)
            if point_name == _last_nearby_point.name then
                local px, py, pz = getCharCoordinates(PLAYER_PED)

                if is_within_distance_3d(px, py, pz, _last_nearby_point.position.x, _last_nearby_point.position.y, _last_nearby_point.position.z, 5.0) then
                    sampSendChat("/capture")
                end
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local point, captured_by = text:match("^.- has taken control of the (.-) for (.-)%.$")
                if point and captured_by and _points[point] then
                    return { point, captured_by }
                end
            end
            return false
        end,
        function(point, captured_by)
            _points[point].owner = captured_by
            _points[point].hours = 25

            _end_point_war()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.GRAD2 and not _active_point_war.refresh_timer:is_paused() and text == "No family has capped the point or the point is not ready to be capped."
        end,
        function()
            _end_point_war()

            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text == "Point Info:"
        end,
        function()
            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local point_name, captured_by, time_left = text:match(
                    "^%* (.-) | Capper: .- | .-: (.-) | Time left: (.-)$")

                if point_name and captured_by and time_left then
                    if _points[point_name] then
                        return { point_name, captured_by, time_left }
                    end
                end
            end
            return false
        end,
        function(point_name, captured_by, time_left)
            if time_left == "Less than 1 minute" then
                time_left = 1
            else
                time_left = tonumber(time_left:match("(%d+)")) or 0
            end

            _start_point_war(point_name, captured_by, time_left)

            return is_command_self_sent("pointinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local point_name, captured_by = text:match(
                    "^.- is attempting to take over of the (.-) for (.-), they'll own it in 10 minutes.$")

                if point_name and captured_by then
                    if _points[point_name] then
                        return { point_name, captured_by }
                    end
                end
            end
            return false
        end,
        function(point_name, captured_by)
            _start_point_war(point_name, captured_by, 10)
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.WHITE and text:match("^The time is now %d+:00+%.$")
        end,
        function()
            for _, point in pairs(_points) do
                if point.hours > 0 then
                    point.hours = point.hours - 1
                end
            end
        end
    )
end

local function _register_commands()
    sampRegisterChatCommand(
        "acapp",
        function()
            _config.auto_capture[0] = not _config.auto_capture[0]
            msg(string.format("Auto Cap Point has been %s{FFFFFF}.",
                _config.auto_capture[0] and "{6DFB6D}enabled" or "{FF0000}disabled"))
        end
    )
end

local Points = {}

function Points:get_active_point()
    return _active_point_war
end

function Points:get_next_point()
    local next_turf_name = nil
    local lowest_hours = 25
    for name, point in pairs(_points) do
        if point.hours > 0 and point.hours < lowest_hours then
            lowest_hours = point.hours
            next_turf_name = name
        end
    end
    return next_turf_name
end

function Points:get_point_data(name)
    return _points[name]
end

function Points:register()
    carboneum.load(CONFIG_PATH, _config)
    -- Automatic captures require a fresh opt-in after each script load.
    _config.auto_capture[0] = false

    _register_event_handlers()
    _register_commands()

    _search_point_3d_text()

    _active_point_war.refresh_timer:pause()
    samp_send_hidden_command("points")


end

function Points:get_config()
    return _config
end

function Points:get_overlay_config()
    return _config.overlay
end

function Points:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function Points:render_ui_settings()
    imgui.DrawChild("Points", function(width)
        imgui.Text("Show upcoming point war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_overlay_upcoming_war", _config.overlay.display_next_information)

        imgui.Separator()

        imgui.Text("Show active point war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_overlay_active_war", _config.overlay.display)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Capture##points", function(width)
        imgui.Text("Automatically capture points as soon as they become available - /acapp")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##points_auto_capture", _config.auto_capture)
    end)


end

return Points

end

package.preload['src.components.Turfs'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\components\Turfs.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local Timer = require("src.core.Timer")

local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")

local CONFIG_PATH = "config/Leone Menu/turfs.json"

local default_data = {
    auto_capture = imgui.new.bool(false),
    spam_capture = imgui.new.bool(false),
    spam_interval = imgui.new.float(10),

    overlay = Overlay.setup_overlay_defaults(
        true,
        0.015,
        0.34,
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
default_data.overlay.display_inside_interiors = imgui.new.bool(false)
default_data.overlay.display_next_information = imgui.new.bool(true)
default_data.overlay.display_war_information = imgui.new.bool(true)

local _config = default_data

local _turfs = {
    ["East Beach"] = { min_x = 2725.0, min_y = -1140.5, max_x = 2962.0, max_y = -1645.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Las Colinas"] = { min_x = 1852.0, min_y = -939.5, max_x = 2961.0, max_y = -1140.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Playa del Seville"] = { min_x = 2568.0, min_y = -1645.5, max_x = 2962.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Los Flores"] = { min_x = 2570.0, min_y = -1140.5, max_x = 2725.0, max_y = -1644.5, owner = "{2641FE}Neutral", hours = 0 },
    ["East Los Santos East"] = { min_x = 2434.0, min_y = -1140.5, max_x = 2572.0, max_y = -1589.5, owner = "{2641FE}Neutral", hours = 0 },
    ["East Los Santos West"] = { min_x = 2291.0, min_y = -1140.5, max_x = 2434.0, max_y = -1589.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Jefferson"] = { min_x = 2063.0, min_y = -1140.5, max_x = 2292.0, max_y = -1588.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Glen Park"] = { min_x = 1822.0, min_y = -1143.5, max_x = 2062.0, max_y = -1588.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Ganton"] = { min_x = 2202.0, min_y = -1588.5, max_x = 2570.0, max_y = -1741.5, owner = "{2641FE}Neutral", hours = 0 },
    ["North Willowfield"] = { min_x = 2202.0, min_y = -1739.5, max_x = 2570.0, max_y = -1932.5, owner = "{2641FE}Neutral", hours = 0 },
    ["South Willowfield"] = { min_x = 2202.0, min_y = -1931.5, max_x = 2570.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Idlewood"] = { min_x = 1822.0, min_y = -1588.5, max_x = 2202.0, max_y = -1953.5, owner = "{2641FE}Neutral", hours = 0 },
    ["El Corona"] = { min_x = 1687.0, min_y = -1954.5, max_x = 2201.0, max_y = -2161.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Little Mexico"] = { min_x = 1687.0, min_y = -1601.5, max_x = 1821.0, max_y = -1954.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Commerce"] = { min_x = 1342.0, min_y = -1491.5, max_x = 1821.0, max_y = -1601.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Pershing Square"] = { min_x = 1316.0, min_y = -1601.5, max_x = 1687.0, max_y = -1873.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Verdant Bluffs"] = { min_x = 917.0, min_y = -1873.5, max_x = 1686.0, max_y = -2162.5, owner = "{2641FE}Neutral", hours = 0 },
    ["LSI Airport"] = { min_x = 953.0, min_y = -2162.5, max_x = 2178.0, max_y = -2786.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Ocean Docks"] = { min_x = 2178.0, min_y = -2162.5, max_x = 2961.0, max_y = -2785.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Downtown Los Santos"] = { min_x = 1342.0, min_y = -1143.5, max_x = 1823.0, max_y = -1491.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Mulholland Intersection"] = { min_x = 1347.0, min_y = -933.5, max_x = 1852.0, max_y = -1143.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Temple"] = { min_x = 631.0, min_y = -933.5, max_x = 1347.0, max_y = -1142.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Mulholland"] = { min_x = 631.0, min_y = -667.5, max_x = 1582.0, max_y = -933.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Market"] = { min_x = 917.0, min_y = -1142.5, max_x = 1342.0, max_y = -1602.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Vinewood"] = { min_x = 631.0, min_y = -1142.5, max_x = 917.0, max_y = -1403.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Marina"] = { min_x = 631.0, min_y = -1403.5, max_x = 918.0, max_y = -1742.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Verona Beach"] = { min_x = 917.0, min_y = -1601.5, max_x = 1316.0, max_y = -1873.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Richman"] = { min_x = 59.0, min_y = -933.5, max_x = 631.0, max_y = -1295.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Rodeo"] = { min_x = 59.0, min_y = -1295.5, max_x = 631.0, max_y = -1742.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Santa Maria Beach"] = { min_x = 60.0, min_y = -1742.5, max_x = 918.0, max_y = -2107.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Dillimore"] = { min_x = 555.0, min_y = -396.0, max_x = 866.0, max_y = -667.0, owner = "{2641FE}Neutral", hours = 0 },
    ["Blueberry"] = { min_x = 78.0, min_y = 79.0, max_x = 393.0, max_y = -205.0, owner = "{2641FE}Neutral", hours = 0 },
    ["Montgomery"] = { min_x = 1120.0, min_y = 506.5, max_x = 1527.0, max_y = 120.5, owner = "{2641FE}Neutral", hours = 0 },
    ["Palomino Creek"] = { min_x = 2094.0, min_y = 276.5, max_x = 2575.0, max_y = -158.5, owner = "{2641FE}Neutral", hours = 0 },
}

local _active_turf_war = {
    refresh_timer = Timer.new(imgui.new.float(45)),

    name = "",
    captured_by = "",
    time_left = 0,
}

local spam_capture_timer = Timer.new(_config.spam_interval)

local Turfs = {}

local function _send_system_priority_command(command)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt32(bs, #command)
    raknetBitStreamWriteString(bs, command)
    raknetSendRpcEx(50, bs, 0, 8, 0, false)
    raknetDeleteBitStream(bs)
end

local function _end_turf_war()
    _active_turf_war.refresh_timer:pause()

    _active_turf_war.name = ""
    _active_turf_war.captured_by = ""
    _active_turf_war.time_left = 0
end

local function _start_turf_war(name, captured_by, time_left)
    _active_turf_war.refresh_timer:resume()

    _active_turf_war.name = name
    _active_turf_war.captured_by = captured_by
    _active_turf_war.time_left = time_left
end

local function _register_event_handlers()

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text:match("^Welcome to Horizon Roleplay, .-%.$")
        end,
        function()
            samp_send_hidden_command("turfs")
        end
    )

    shared.event_handler:register(
        "SHOW_DIALOG",
        function(id, style, title, button1, button2, text)
            if title:match("^%{FFA500%}Horizon Roleplay Turfs %- %{FFFFFF%}Page %d+%/%d+$") then
                return { id, title, text }
            end
            return false
        end,
        function(id, title, text)
            local fetched_turfs = {}
            for name, owner, hours in text:gmatch("{FFA500}Name:{FFFFFF} (.-) {FFA500}| Owner:(.-) {FFA500}| Captured By:{FFFFFF} .- {FFA500}| Hours:{FFFFFF} (%d+)") do
                owner = owner:gsub("%s+", "", 1)

                if owner == "{FFFFFF}Neutral" then
                    owner = "{2641FE}Neutral"
                end

                table.insert(fetched_turfs, { name = name, owner = owner, hours = tonumber(hours) })
            end

            for _, fetched_turf in ipairs(fetched_turfs) do
                if _turfs[fetched_turf.name] then
                    _turfs[fetched_turf.name].owner = fetched_turf.owner
                    _turfs[fetched_turf.name].hours = fetched_turf.hours
                end

                if fetched_turf.hours == 0 and _active_turf_war.refresh_timer:is_paused() then
                    samp_send_hidden_command("turfinfo")
                end
            end

            if title == "{FFA500}Horizon Roleplay Turfs - {FFFFFF}Page 1/2" and is_command_self_sent("turfs") == false then
                sampSendDialogResponse(id, 1, 1, "")
            end

            return is_command_self_sent("turfs")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW and _config.auto_capture[0] and not Player:is_on_admin_duty() then
                local turf_name = text:match("^(.-) has become available for capture%.$")
                if turf_name then
                    return { turf_name }
                end
            end
            return false
        end,
        function(turf_name)
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            local current_turf_name = Turfs:get_current_turf(px, py)

            if current_turf_name and current_turf_name == turf_name then
                _send_system_priority_command("/capturf")
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.NEWS and text == "Turf Info:"
        end,
        function()
            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.WHITE then
                local turf_name, captured_by, time_left = text:match(
                    "^%* (.-) | Capper: .- | .-: (.-) | Time left: (.-)$")

                if turf_name and captured_by and time_left then
                    if _turfs[turf_name] then
                        return { turf_name, captured_by, time_left }
                    end
                end
            end
            return false
        end,
        function(turf_name, captured_by, time_left)
            if time_left == "Less than 1 minute" then
                time_left = 1
            else
                time_left = tonumber(time_left:match("(%d+)")) or 0
            end

            _start_turf_war(turf_name, captured_by, time_left)

            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local turf_name, captured_by = text:match(
                    "^.- is attempting to take control of (.-) for (.-) %(15 minutes remaining%)%.$")

                if turf_name and captured_by then
                    if _turfs[turf_name] then
                        return { turf_name, captured_by }
                    end
                end
            end
            return false
        end,
        function(turf_name, captured_by)
            _start_turf_war(turf_name, captured_by, 15)
        end
    )

    shared.event_handler:register(
        "GANG_ZONE_FLASH",
        function(zoneid, color)
            return zoneid >= 0 and zoneid <= 33
        end,
        function()
            if _active_turf_war.refresh_timer:is_paused() then
                lua_thread.create(function()
                    wait(0)
                    samp_send_hidden_command("turfinfo")
                end)
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            if color == Colors.YELLOW then
                local turf, captured_by = text:match("^.- has taken control of (.-) for (.-)%.$")
                if turf and captured_by and _turfs[turf] then
                    return { turf, captured_by }
                end
            end
            return false
        end,
        function(turf, captured_by)
            _turfs[turf].owner = captured_by
            _turfs[turf].hours = 73

            _end_turf_war()
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.GRAD2 and not _active_turf_war.refresh_timer:is_paused() and text == "Nobody is attempting to capture any turfs or no turfs are available for capture yet."
        end,
        function()
            _end_turf_war()

            return is_command_self_sent("turfinfo")
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(color, text)
            return color == Colors.WHITE and text:match("^The time is now %d+:00+%.$")
        end,
        function()
            for _, turf in pairs(_turfs) do
                if turf.hours > 0 then
                    turf.hours = turf.hours - 1
                end
            end
        end
    )

    shared.event_handler:register(
        "PED_TICK",
        function(x, y, z)
            if _config.spam_capture[0] and spam_capture_timer:is_ready() and not Player:is_on_admin_duty() then
                return { x, y, z }
            end
            return false
        end,
        function(x, y, z)
            local turf_name = Turfs:get_current_turf(x, y)

            if turf_name and _turfs[turf_name].hours <= 1 then
                spam_capture_timer:trigger()
                _send_system_priority_command("/capturf")
            end
        end
    )
end

local function _register_commands()
    sampRegisterChatCommand(
        "acapt",
        function()
            _config.auto_capture[0] = not _config.auto_capture[0]
            msg(string.format("Auto Cap Turf has been %s{FFFFFF}.",
                _config.auto_capture[0] and "{6DFB6D}enabled" or "{FF0000}disabled"))
        end
    )

    sampRegisterChatCommand(
        "spamt",
        function(args)
            if args~='' then
                local interval=tonumber(args)
                if not interval or interval<1 or interval>3600 then return msg('USAGE: /spamt [1-3600 seconds]') end
                _config.spam_interval[0]=interval
                return msg(string.format('Spam Cap Turf delay set to {6DFB6D}%g s',interval))
            end
            _config.spam_capture[0] = not _config.spam_capture[0]
            if _config.spam_capture[0] then
                msg(string.format('Spam Cap Turf is {6DFB6D}enabled{FFFFFF}, {6DFB6D}%gs{FFFFFF} delay. {6DFB6D}/spamt amount to edit delay',_config.spam_interval[0]))
            else msg('Spam Cap Turf has been {FF0000}disabled') end
        end
    )

    sampRegisterChatCommand(
        "findturf",
        function(args)
            if args == "" then
                return msg("Usage: /findturf <turf name>")
            end

            local lower_name = args:lower()
            for name, turf in pairs(_turfs) do
                if name:lower():find(lower_name, 1, true) then
                    local center_x = (turf.min_x + turf.max_x) / 2
                    local center_y = (turf.min_y + turf.max_y) / 2
                    placeWaypoint(center_x, center_y, 5)
                    msg(string.format("Waypoint placed to the center of turf %s.", name))
                    return
                end
            end

            msg(string.format("Turf '{BE60F7}%s{FFFFFF}' not found.", args))
        end
    )
end

function Turfs:get_active_turf()
    return _active_turf_war
end

function Turfs:get_current_turf(x, y)
    for name, turf in pairs(_turfs) do
        if x >= turf.min_x and x <= turf.max_x and y >= turf.max_y and y <= turf.min_y then
            return name
        end
    end
    return nil
end

function Turfs:get_next_turf()
    local next_turf_name = nil
    local lowest_hours = 73
    for name, turf in pairs(_turfs) do
        if turf.hours > 0 and turf.hours < lowest_hours then
            lowest_hours = turf.hours
            next_turf_name = name
        end
    end
    return next_turf_name
end

function Turfs:get_turf_data(name)
    return _turfs[name]
end

function Turfs:get_all_turfs()
    return _turfs
end

function Turfs:register()
    carboneum.load(CONFIG_PATH, _config)
    -- Automatic captures require a fresh opt-in after each script load.
    _config.auto_capture[0] = false

    _register_event_handlers()
    _register_commands()

    _active_turf_war.refresh_timer:pause()
    samp_send_hidden_command("turfs")


end

function Turfs:get_config()
    return _config
end

function Turfs:get_overlay_config()
    return _config.overlay
end

function Turfs:save_config()
    carboneum.save(CONFIG_PATH, _config)
end

function Turfs:render_ui_settings()
    imgui.DrawChild("Turfs", function(width)
        imgui.Text("Show upcoming turf war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_overlay_upcoming_war", _config.overlay.display_next_information)

        imgui.Separator()

        imgui.Text("Show active turf war info")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_overlay_active_war", _config.overlay.display_war_information)

        imgui.Separator()

        imgui.Text("Enable overlay inside interiors")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_overlay_inside_interiors", _config.overlay.display_inside_interiors)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Capture##turfs", function(width)
        imgui.Text("Automatically capture turfs as soon as they become available - /acapt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_auto_capture", _config.auto_capture)

        imgui.Separator()

        imgui.Text("Run capture command periodically - /spamt")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("##turfs_spam_capture", _config.spam_capture)

        if _config.spam_capture[0] then
            imgui.Separator()

            imgui.Text("Capture spam interval")
            imgui.SameLine(width - 40)
            imgui.SetNextItemWidth(40)
            imgui.DragFloat("##turfs_spam_interval", _config.spam_interval, 1, 1, 10.0, "%.1fs")
        end
    end)


end

return Turfs

end

package.preload['src.components.Vehicles'] = function()
-- Scoped dialog automation for storage, tow and GPS; row numbers are one-based.
local shared=require('src.shared')
local R=require('src.core.Rules')
local Config=require('src.core.Config')
local MainWindow=require('src.ui.MainWindow')
local V={}
local cache_file='config/Leone Menu/vehicle-storage.json'
local cache={}
local pending
local spawned_at, startup_requested, refresh_at
local visible_storage
local changes={}
local font, font_size

local function identity()
    if not sampIsLocalPlayerSpawned or not sampIsLocalPlayerSpawned()
        or not sampGetCurrentServerAddress then return end
    local ok,id=sampGetPlayerIdByCharHandle(PLAYER_PED)
    local host,port=sampGetCurrentServerAddress()
    local name=ok and sampGetPlayerNickname(id)
    if name and host and port then return host..':'..port..'/'..name end
end

local function storage_row(row)
    if row then return row:match('^Vehicle:%s*(.-)%s*|%s*Status:%s*(%a+)') end
end

local function cache_storage(rows)
    local key=identity()
    if not key then return end
    local vehicles={}
    for slot,row in ipairs(rows) do
        local name,status=storage_row(row)
        if name and name~='' and (status=='Stored' or status=='Spawned') then
            vehicles[#vehicles+1]={slot=slot,name=name,spawned=status=='Spawned'}
        elseif row~='' and row:lower()~='empty' then
            return -- Keep the previous list if the server layout changed.
        end
    end
    if #rows==0 then return end
    cache[key]=vehicles
    Config.save(cache_file,cache)
    return true
end

local function prune_changes(key,now)
    for i=#changes,1,-1 do
        local change=changes[i]
        if change.key~=key or now>change.expires then table.remove(changes,i) end
    end
end

local function track_change(rows,slot)
    local key=identity()
    if not key then return end
    local now=getGameTimer()
    refresh_at=now+500
    prune_changes(key,now)
    local name,status=storage_row(rows[slot])
    if name and (status=='Stored' or status=='Spawned') then
        changes[#changes+1]={key=key,slot=slot,name=name,spawned=status=='Stored',expires=now+6000}
    end
end

local function confirm_change(name,spawned)
    local key=identity()
    if not key then return end
    prune_changes(key,getGameTimer())
    for i,change in ipairs(changes) do
        if change.name==name and change.spawned==spawned then
            table.remove(changes,i)
            local vehicles=cache[key]
            if type(vehicles)~='table' then return end
            for _,vehicle in ipairs(vehicles) do
                if type(vehicle)=='table' and vehicle.slot==change.slot and vehicle.name==name then
                    if vehicle.spawned~=spawned then
                        vehicle.spawned=spawned
                        Config.save(cache_file,cache)
                    end
                    if #changes==0 then refresh_at=nil end
                    return
                end
            end
            return
        end
    end
end

local function release_font()
    if font then renderReleaseFont(font);font=nil end
end

local function draw_preview()
    if not sampIsChatInputActive() or sampIsDialogActive() or not pass_render_checks()
        then return end
    local command,args=R.trim(sampGetChatInputText() or ''):lower():match('^/(%a+)(.*)$')
    if command~='vst' and command~='fv' and command~='vtow' then return end
    if args~='' and not args:match('^%s+%d+$') then return end
    local key=identity()
    local vehicles=key and cache[key]
    if type(vehicles)~='table' or #vehicles==0 then return end
    local width,height=getScreenResolution()
    local old_size=math.max(10,math.min(20,math.floor(height/90+0.5)))
    local compact_size=math.floor(old_size*0.35+0.5)
    -- MoonLoader creates fonts at whole-pixel heights.
    local size=math.floor(compact_size*1.35*1.05+0.5)
    if font_size~=size or not font then
        release_font()
        font=renderCreateFont('Arial',size,5)
        font_size=size
    end
    if not font then return end
    local gap=math.max(32,math.floor(height*0.055))
    local y=height*0.36
    -- WindowBottom is the last rendered chat row. Leave room for the input box
    -- below it as well as a visible gap, even with a one-line chat window.
    local chat=sampGetChatInfoPtr and sampGetChatInfoPtr()
    local page_size=chat and chat>0 and readMemory(chat,4,false)
    if page_size and page_size>=1 and page_size<=100
        and readMemory(chat+8,4,false)==sampGetChatDisplayMode() then
        local bottom=readMemory(chat+0x12E,4,false)
        if bottom and bottom>0 and bottom<=height then
            y=math.max(math.floor(height*0.11),bottom+gap)
        end
    end
    local x=math.floor(math.max(10,width*0.012))
    local step=renderGetFontDrawHeight(font)+1
    for _,vehicle in ipairs(vehicles) do
        if y+step>height then break end
        if type(vehicle)=='table' and type(vehicle.slot)=='number' and vehicle.slot%1==0
            and vehicle.slot>=1 and vehicle.slot<=50 and type(vehicle.name)=='string'
            and #vehicle.name<=80 and not vehicle.name:find('[%c{}]') then
            local prefix=('%d. '):format(vehicle.slot)
            if vehicle.spawned==true then
                renderFontDrawText(font,prefix,x,y,0xFFFFFFFF)
                renderFontDrawText(font,vehicle.name,x+renderGetFontDrawTextLength(font,prefix),y,0xFF00FF00)
            else
                renderFontDrawText(font,prefix..vehicle.name,x,y,0xFFFFFFFF)
            end
            y=y+step
        end
    end
end
local function stop(text,id,index)
    pending=nil
    if id then sampSendDialogResponse(id,0,index or 0,'') end
    if text then msg(text) end
end
local function query()
    if not pending then return end
    pending.deadline=os.clock()+6
    samp_send_hidden_command(pending.kind=='find' and 'trackcar' or 'vst')
end
function V.rows(text,style)
    local rows={}
    for row in (text..'\n'):gmatch('(.-)\n')do
        local plain=R.trim(R.strip(row))
        rows[#rows+1]=plain
    end
    if style==5 then table.remove(rows,1)end
    while rows[#rows]=='' do table.remove(rows) end
    return rows
end
local function begin(kind,args)
    args=R.trim(args)
    if kind=='toggle' and args=='' then
        if pending and pending.kind=='cache' then
            pending=nil -- The startup reply can now serve the user's visible /vst.
        else
            pending=nil
            samp_send_hidden_command('vst')
        end
        return
    end
    local slot=tonumber(args)
    if not slot or slot%1~=0 or slot<1 or slot>50 then return msg('USAGE: /'..({toggle='vst',tow='vtow',find='fv'})[kind]..' [Slot Number]')end
    local reuse=pending and pending.kind=='cache' and kind~='find'
    if pending and not reuse then return msg('Please wait for the current vehicle request.')end
    local deadline=reuse and pending.deadline
    pending={kind=kind,slot=slot,stage='initial',polls=0,deadline=deadline}
    if not reuse then query() end
end
function V:register()
    local saved=Config.read(cache_file)
    if saved then
        local decoded=require('dkjson').decode(saved)
        if type(decoded)=='table' then cache=decoded end
    end
    addEventHandler('onScriptTerminate',function(script)
        if script==thisScript() then release_font() end
    end)
    shared.event_handler:register('PED_TICK',function()
        return (not startup_requested or refresh_at~=nil) and identity()~=nil
    end,function()
        local now=getGameTimer()
        spawned_at=spawned_at or now
        local due=not startup_requested and now-spawned_at>=11000 or refresh_at and now>=refresh_at
        if due and not pending and not sampIsDialogActive()
            and not sampIsChatInputActive() and not MainWindow:is_open() and not is_cursor_active() then
            startup_requested=true
            refresh_at=nil
            pending={kind='cache'}
            query()
        end
    end)
    shared.event_handler:register('PED_TICK',function() return next(cache)~=nil end,draw_preview)
    sampRegisterChatCommand('vst',function(args)begin('toggle',args)end)
    sampRegisterChatCommand('vtow',function(args)begin('tow',args)end)
    sampRegisterChatCommand('fv',function(args)begin('find',args)end)
    shared.event_handler:register('SHOW_DIALOG',function(id,style,title,b1,b2,text)
        visible_storage=nil
        if not (style==2 or style==4 or style==5)then return false end
        title=R.strip(title)
        if pending and pending.kind=='find' and title=='Vehicle GPS Tracking' then return {id,style,text}end
        if title:match('^Vehicle storage %(empty slots available: %d+%)$')then return {id,style,text,true}end
        return false
    end,function(id,style,text,is_storage)
        local p=pending
        local rows=V.rows(text,style)
        if p and p.kind=='cache' then
            stop(nil,id,0)
            -- A completed reconciliation supersedes earlier unconfirmed changes.
            if cache_storage(rows) then changes={} end
            return false
        end
        if is_storage then cache_storage(rows) end
        if not p or (is_storage and p.kind=='find') then
            if is_storage then visible_storage={id=id,rows=rows} end
            return
        end
        local row=rows[p.slot];local index=p.slot-1
        if not row or row=='' or row:lower()=='empty' then stop('That vehicle slot is empty or unavailable.',id,index);return false end
        if p.kind=='find' or p.kind=='toggle' then
            if p.kind=='toggle' then track_change(rows,p.slot) end
            pending=nil;sampSendDialogResponse(id,1,index,'');return false
        end
        local name,status=storage_row(row)
        if not name or (status~='Spawned' and status~='Stored') then stop('Vehicle list changed; stopped the tow.',id,index);return false end
        if p.stage=='initial' then
            if status=='Stored' then stop("The vehicle you tried towing isn't spawned in, stopped the tow.",id,index);return false end
            p.name=name;p.stage='wait_stored';p.deadline=os.clock()+6
            track_change(rows,p.slot)
            sampSendDialogResponse(id,1,index,'')
            lua_thread.create(function()wait(400);if pending==p then query()end end)
        elseif name~=p.name then stop('Vehicle slot changed; stopped the tow.',id,index)
        elseif status=='Stored' then
            track_change(rows,p.slot)
            pending=nil;sampSendDialogResponse(id,1,index,'')
        else
            p.polls=p.polls+1
            sampSendDialogResponse(id,0,index,'')
            if p.polls>=2 then stop('The vehicle was not stored by the server; stopped the tow.')
            else lua_thread.create(function()wait(500);if pending==p then query()end end)end
        end
        return false
    end)
    shared.event_handler:register('SEND_DIALOG_RESPONSE',function(id)
        return visible_storage and id==visible_storage.id
    end,function(_,button,index)
        local rows=visible_storage.rows
        visible_storage=nil
        if button==1 and type(index)=='number' then track_change(rows,index+1) end
    end)
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)
        local plain=R.strip(text)
        local name=plain:match('^You have stored your (.-)%. The vehicle has been despawned%.$')
        if name then return {name,false} end
        name=plain:match('^You have taken your (.-) out of storage%. The vehicle has been spawned at the last parking location%.$')
        if name then return {name,true} end
        return false
    end,confirm_change)
    shared.event_handler:register('PED_TICK',function()return pending and os.clock()>pending.deadline end,function()stop(pending.kind~='cache' and 'Vehicle request timed out; stopped.' or nil)end)
end
return V

end

package.preload['src.core.Colors'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\core\Colors.lua

local function to_signed(hex)
    if hex >= 0x80000000 then
        return hex - 0x100000000
    end
    return hex
end

local Colors          = {}

Colors.ALLDEPT        = to_signed(0xFF8282AA)
Colors.DBLUE          = to_signed(0x2641FEAA)
Colors.TEAM_BLUE      = to_signed(0x2641FE00)
Colors.TEAM_MED_COLOR = to_signed(0xFF828200)
Colors.DEPTRADIO      = to_signed(0xFFD7004A)
Colors.RADIO          = to_signed(0x8D8DFFFF)
Colors.FREQUENCY      = to_signed(0x6DFB6DFF)
Colors.NEWS           = to_signed(0xFFA500AA)

Colors.WHITE          = to_signed(0xFFFFFFAA)
Colors.GREY           = to_signed(0xAFAFAFAA)
Colors.GRAD1          = to_signed(0xB4B5B7FF)
Colors.GRAD2          = to_signed(0xBFC0C2FF)
Colors.ORANGE         = to_signed(0xFF8000FF)
Colors.LIGHTBLUE      = to_signed(0x33CCFFAA)
Colors.YELLOW         = to_signed(0xFFFF00AA)
Colors.YELLOW2        = to_signed(0xE8E82EFF)
Colors.LIGHTRED       = to_signed(0xFF6347AA)
Colors.GREEN          = to_signed(0x049C71AA)

return Colors

end

package.preload['src.core.Config'] = function()
-- Leone persistence; preserves Sputnik's table/cdata settings API.
local ffi = require('ffi')
local json = require('dkjson')
local Config = {}
local function encode_value(v)
    if type(v) == 'cdata' then
        local n = assert(tonumber(tostring(ffi.typeof(v)):match('%[(%d+)%]')), 'Unsupported config cdata')
        local a = {}
        for i=0,n-1 do
            if type(v[i])=='boolean' then a[i+1]=v[i] else a[i+1]=tonumber(v[i]) end
        end
        return {__array=a}
    elseif type(v) == 'table' then
        local out = {}
        for k,x in pairs(v) do out[k] = encode_value(x) end
        return out
    end
    return v
end
local function merge(target, data)
    for source_key,v in pairs(data) do
        local k=source_key
        if type(k)=='string' and tonumber(k) and target[tonumber(k)]~=nil then k=tonumber(k) end
        local old = target[k]
        if type(old) == 'cdata' and type(v) == 'table' and type(v.__array) == 'table' then
            local n = assert(tonumber(tostring(ffi.typeof(old)):match('%[(%d+)%]')), 'Unsupported config cdata')
            for i=0,n-1 do
                local x=v.__array[i+1]
                -- Older builds lost false bools and saved an empty __array.
                if x==nil and type(old[i])=='boolean' then old[i]=false
                elseif type(x)==type(old[i]) then old[i]=x end
            end
        elseif type(old)=='table' and type(v)=='table' and not v.__array then merge(old,v)
        elseif old==nil or type(old)==type(v) then target[k]=v end
    end
end
function Config.path(p)
    if p:match('^%a:[/\\]') then return p end
    return getWorkingDirectory() .. '/' .. p
end
function Config.write(path, text)
    path=Config.path(path)
    local tmp=path..'.tmp'
    local f,err=io.open(tmp,'wb'); if not f then return false,err end
    local ok,why=f:write(text); f:close()
    if not ok then return false,why end
    local check=io.open(tmp,'rb'); if not check then return false,'Cannot verify temporary file' end
    local same=check:read('*a')==text; check:close()
    if not same then return false,'Temporary file differs' end
    -- Windows atomic replacement with write-through; old file remains intact on failure.
    pcall(ffi.cdef,'int __stdcall MoveFileExA(const char*,const char*,unsigned long);')
    if ffi.load('kernel32').MoveFileExA(tmp,path,9)==0 then return false,'Atomic replacement failed' end
    return true
end
function Config.read(path)
    local f=io.open(Config.path(path),'rb'); if not f then return nil end
    local s=f:read('*a');f:close();return s
end
function Config.save(path, settings)
    local ok,data=pcall(function() return json.encode(encode_value(settings),{indent=true}) end)
    if not ok then return false,data end
    local old=Config.read(path)
    if old==data then return true end
    if old and type(json.decode(old))=='table' then Config.write(path..'.bak',old) end
    local success,err=Config.write(path,data)
    if not success then print('[Leone Menu] Config save failed: '..tostring(err)) end
    return success,err
end
function Config.load(path, settings)
    local data=Config.read(path)
    if not data then return Config.save(path,settings) end
    local parsed,_,err=json.decode(data)
    if type(parsed)~='table' or err then
        print('[Leone Menu] Invalid config; trying backup: '..path)
        parsed=json.decode(Config.read(path..'.bak') or '')
    end
    if type(parsed)=='table' then merge(settings,parsed) end
    return true
end
return Config

end

package.preload['src.core.CustomLocations'] = function()
local Rules = require('src.core.Rules')

local locations = {
    {name="All Saints Hospital",min_x=1133.3644,max_x=1199.4504,min_y=-1400.8804,max_y=-1273.7079,point=false},
    {name="County General Hospital",min_x=1981.6985,max_x=2112.8921,min_y=-1473.1101,max_y=-1341.7203,point=false},
    {name="Maximus Club",min_x=1813.8079,max_x=1944.1582,min_y=-1760.2096,max_y=-1606.4039,point=false},
    {name="Pizza Stacks",min_x=2098.3291,max_x=2134.1362,min_y=-1831.5007,max_y=-1759.5227,point=false},
    {name="Downtown LS Bank",min_x=1371.334,max_x=1531.8296,min_y=-1039.7273,max_y=-933.7825,point=false},
    {name="Rodeo Bank",min_x=500.8312,max_x=633.2853,min_y=-1358.8105,max_y=-1201.9067,point=false},
    {name="Dice Casino",min_x=747.7726,max_x=788.3983,min_y=-1595.5197,max_y=-1516.7189,point=false},
    {name="Star Tower",min_x=1499.6473,max_x=1596.3043,min_y=-1402.3785,max_y=-1302.6461,point=false},
    {name="East Beach Stadium",min_x=2635.2527,max_x=2844.8594,min_y=-1898.3109,max_y=-1647.9591,point=false},
    {name="Glen Park BM",min_x=1961.808,max_x=2080.8647,min_y=-1321.8481,max_y=-1253.4957,point=false},
    {name="LSPD HQ",min_x=1522.7148,max_x=1612.5985,min_y=-1739.2374,max_y=-1584.5906,point=false},
    {name="FBI HQ",min_x=232.9287,max_x=427.3033,min_y=-1571.7903,max_y=-1485.9653,point=false},
    {name="ARES HQ",min_x=2762.7317,max_x=2852.2761,min_y=-1156.9515,max_y=-1040.8756,point=false},
    {name="MP1",min_x=1333.1392,max_x=1464.0436,min_y=-1439.5022,max_y=-1231.2352,point=true},
    {name="FFC",min_x=2423.988,max_x=2714.2747,min_y=-2158.8818,max_y=-2062.1416,point=true},
    {name="Drug Factory",min_x=17.9806,max_x=204.9483,min_y=-345.4443,max_y=-198.3929,point=true},
    {name="Blueberry Hospital",min_x=88.0542,max_x=142.472,min_y=-200.4079,max_y=-148.0842,point=false},
    {name="MF1",min_x=2056.9868,max_x=2306.6816,min_y=-2318.6392,max_y=-2271.5701,point=true},
    {name="MP2",min_x=2312.9573,max_x=2548.6943,min_y=-2054.2615,max_y=-1972.2751,point=true},
    {name="Drug House",min_x=2100.1726,max_x=2208.9001,min_y=-1728.1006,max_y=-1635.2883,point=true},
    {name="Crack Lab",min_x=2298.4644,max_x=2373.3162,min_y=-1208.7295,max_y=-1117.1232,point=true},
    {name="MF2",min_x=2238.957,max_x=2294.7288,min_y=-1139.167,max_y=-1027.7941,point=true},
    {name="AEC",min_x=2610.1086,max_x=2867.8977,min_y=-2581.8206,max_y=-2330.5796,point=true},
    {name="Sprunk Factory",min_x=1313.7975,max_x=1341.3224,min_y=215.729,max_y=327.1318,point=true},
    {name="MP3",min_x=2117.3782,max_x=2251.2034,min_y=-145.1033,max_y=37.5504,point=true},
    {name="MF3",min_x=-656.5953,max_x=-446.9016,min_y=-595.3939,max_y=-442.6551,point=true},
}

-- Interiors reuse the exterior location names and point flags. GTA shares
-- interior IDs across different maps, so the ID alone is never a match.
local interiors = {
    ["Drug House"] = {
        id=5, x=321.4866, y=1121.5527, radius=60,
        min_z=1073.8828, max_z=1093.8828,
    },
    ["Crack Lab"] = {
        id=5,
        -- One unit of XY margin also includes the known interior entry.
        min_x=2318.0588, max_x=2350.8315, min_y=-1189.2571, max_y=-1170.6425,
        min_z=1022.9766, max_z=1036.9766,
        entrance={id=5,x=2352.2275,y=-1180.7423,radius=5,min_z=1021.9766,max_z=1033.9766},
    },
    ["Drug Factory"] = {
        id=1, min_z=997.9554, max_z=1010.7222,
        polygon={
            {2204.3997,1555.9644}, {2204.3997,1547.3065},
            {2218.9817,1547.3325}, {2224.5552,1554.9347},
            {2225.6265,1573.1626}, {2231.1577,1573.1626},
            {2233.5505,1578.0958}, {2233.5510,1592.4717},
            {2231.1499,1597.7941}, {2226.5596,1621.1069},
            {2195.7124,1627.6812}, {2169.1184,1627.6812},
            {2168.6919,1593.8151}, {2168.7085,1581.6128},
            {2171.2827,1576.2745}, {2195.3899,1576.2628},
            {2214.3999,1579.7954}, {2215.3623,1566.9266},
            {2214.2354,1557.1410}, {2204.3997,1555.9750},
        },
    },
}

local function in_polygon(x, y, vertices)
    local inside = false
    local previous = vertices[#vertices]
    for _, vertex in ipairs(vertices) do
        local ax, ay = previous[1], previous[2]
        local bx, by = vertex[1], vertex[2]
        local dx, dy = bx - ax, by - ay
        -- Include corners and edges to account for saved coordinate rounding.
        local epsilon = 0.005
        if x >= math.min(ax, bx) - epsilon and x <= math.max(ax, bx) + epsilon
            and y >= math.min(ay, by) - epsilon and y <= math.max(ay, by) + epsilon
            and math.abs(dx * (y - ay) - dy * (x - ax)) <= epsilon * (math.abs(dx) + math.abs(dy)) then
            return true
        end
        if (ay > y) ~= (by > y) and x < ax + dx * (y - ay) / dy then
            inside = not inside
        end
        previous = vertex
    end
    return inside
end

local function in_interior(x, y, z, id, shape)
    if not shape or shape.id ~= id or z < shape.min_z or z > shape.max_z then return false end
    if shape.radius then
        local dx, dy = x - shape.x, y - shape.y
        return dx * dx + dy * dy <= shape.radius * shape.radius
    end
    if shape.polygon then return in_polygon(x, y, shape.polygon) end
    return Rules.in_box(x, y, shape)
end

function locations.find(x, y, z, interior, point_only)
    for _, location in ipairs(locations) do
        if not point_only or location.point then
            if interior == 0 and Rules.in_box(x, y, location) then return location end
            local shape=interiors[location.name]
            if shape and (in_interior(x,y,z,interior,shape) or in_interior(x,y,z,interior,shape.entrance)) then
                return location
            end
        end
    end
end

function locations.has_interior(name)
    return interiors[name]~=nil
end

return locations

end

package.preload['src.core.EventHandler'] = function()
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

end

package.preload['src.core.GangImport'] = function()
-- Five-minute in-session cache; hiding the list never repeats /gangs.
local R=require('src.core.Rules')
local shared=require('src.shared')
local G={rows={},visible=false,importing=false,cached_at=nil,last_request=-300}
function G:toggle()
    self.visible=not self.visible
    if not self.visible or self.importing then return end
    local now=os.clock()
    if self.cached_at and now-self.cached_at<300 then return end
    if now-self.last_request<6 then return end
    self.buffer={};self.importing=true;self.started=now;self.last=nil;self.last_request=now
    samp_send_hidden_command('gangs')
end
local function finish()
    G.importing=false
    if #G.buffer>0 then G.rows=G.buffer;G.cached_at=os.clock() end
    G.buffer=nil;G.last=nil
end
shared.event_handler:register('SERVER_MESSAGE',function(color,text)
    return G.importing and {color,text} or false
end,function(color,text)
    if os.clock()-G.started>6 then finish();return end
    local row=R.gang(text,color)
    if row then
        for _,g in ipairs(G.buffer) do if g.name==row.name then return false end end
        G.buffer[#G.buffer+1]=row;G.last=os.clock();return false
    end
    if R.trim(R.strip(text))=='Gangs:' then return false end
end)
shared.event_handler:register('PED_TICK',function()return G.importing end,function()
    if (G.last and os.clock()-G.last>0.6) or os.clock()-G.started>6 then finish() end
end)
return G

end

package.preload['src.core.HotkeyManager'] = function()
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

end

package.preload['src.core.Rules'] = function()
-- Pure parsing/selection rules shared by runtime and local tests.
local R={}
function R.strip(s) return (s:gsub('{%x%x%x%x%x%x}',''):gsub('~%a~','')) end
function R.trim(s) return s:match('^%s*(.-)%s*$') end
function R.skins(text)
    local out,seen={},{}
    if type(text)~='string' or text:find('[^%d,%s]') then return nil end
    for n in text:gmatch('%d+') do
        n=tonumber(n)
        if n>311 or n==74 then return nil end
        if not seen[n] then out[#out+1]=n;seen[n]=true end
    end
    if #out==0 then return nil end
    return out
end
function R.alliance(html)
    local version=tonumber(html:match('<meta%s+name="leone%-skins%-version"%s+content="(%d+)"%s*/?>'))
    local ids=html:match('<pre%s+id="alliance%-skins">%s*([^<]+)</pre>')
    local skins=ids and R.skins(R.trim(ids))
    if not version or not skins then return nil end
    return {version=version,skins=skins}
end
function R.frequency(text)
    text=R.strip(text)
    local body=text:match('Family MOTD:%s*(.+)')
    if not body then return nil end
    local n=body:match('[Ff]:%s*(%-?%d+)') or body:match('^%s*(%-?%d+)')
    if n and #n:gsub('^-','')<=8 then return tonumber(n) end
end
function R.in_box(x,y,b)
    return x>=b.min_x and x<=b.max_x and y>=b.min_y and y<=b.max_y
end
function R.matches(query,players)
    local exact,partial={},{}
    query=query:lower():gsub(' ','_')
    for _,p in ipairs(players) do
        local name=p.name:lower()
        if (query:match('^%d+$') and p.id==tonumber(query)) or name==query then exact[#exact+1]=p
        elseif not query:match('^%d+$') and name:find(query,1,true) then partial[#partial+1]=p end
    end
    return #exact>0 and exact or partial
end
function R.gang(text,color)
    local plain=R.strip(text)
    local name=plain:match('^%s*%*%s*%d+%.%s*(.-)%s*|')
    if not name or not plain:match('|%s*Leader:') or not plain:match('|%s*Online:%s*%d+') then return nil end
    local prefix=text:match('^(.-)|') or ''
    local hex
    for tag,rest in prefix:gmatch('{(%x%x%x%x%x%x)}([^{}]*)') do
        if rest:find(name,1,true) then hex=tag end
    end
    return {name=R.trim(name),hex=(hex or string.format('%08X',color%4294967296):sub(1,6)):upper()}
end
function R.short_turf(name)
    name=R.trim(R.strip(name or ''))
    local short={['Pershing Square']='Pershing Sq.',['East Los Santos East']='East LS (E)',
        ['East Los Santos West']='East LS (W)',['Downtown Los Santos']='Downtown LS',
        ['Mulholland Intersection']='Mulholland Int.',['North Willowfield']='N. Willowfield',
        ['South Willowfield']='S. Willowfield',['Santa Maria Beach']='Santa Maria',
        ['Playa del Seville']='Playa Seville'}
    return short[name] or name
end
function R.newer(a,b)
    local function parts(v)
        local x,y,z,suffix=v:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
        if not x or (suffix~='' and not suffix:match('^[-+][%w.+%-]+$')) then return nil end
        local pre=suffix:match('^%-([^+]+)')
        return {tonumber(x),tonumber(y),tonumber(z)},pre
    end
    local pa,pre_a=parts(a);local pb,pre_b=parts(b)
    if not pa or not pb then return false end
    for i=1,3 do if pa[i]~=pb[i] then return pa[i]>pb[i] end end
    if not pre_a or not pre_b then return not pre_a and pre_b~=nil end
    local aa,bb={},{}
    for v in pre_a:gmatch('[^.]+') do aa[#aa+1]=v end
    for v in pre_b:gmatch('[^.]+') do bb[#bb+1]=v end
    for i=1,math.max(#aa,#bb) do
        if not aa[i] then return false elseif not bb[i] then return true end
        if aa[i]~=bb[i] then
            local na,nb=tonumber(aa[i]),tonumber(bb[i])
            if na and nb then return na>nb elseif na then return false elseif nb then return true end
            return aa[i]>bb[i]
        end
    end
    return false
end
return R

end

package.preload['src.core.SkinCatalog'] = function()
return {
    {id=0,width=165,height=300},
    {id=1,width=165,height=300},
    {id=2,width=165,height=300},
    {id=3,width=165,height=300},
    {id=4,width=165,height=300},
    {id=5,width=165,height=300},
    {id=6,width=165,height=300},
    {id=7,width=165,height=300},
    {id=8,width=165,height=300},
    {id=9,width=165,height=300},
    {id=10,width=165,height=300},
    {id=11,width=165,height=300},
    {id=12,width=165,height=300},
    {id=13,width=165,height=300},
    {id=14,width=165,height=300},
    {id=15,width=165,height=300},
    {id=16,width=165,height=300},
    {id=17,width=165,height=300},
    {id=18,width=183,height=332},
    {id=19,width=165,height=300},
    {id=20,width=165,height=300},
    {id=21,width=165,height=300},
    {id=22,width=165,height=300},
    {id=23,width=165,height=300},
    {id=24,width=165,height=300},
    {id=25,width=165,height=300},
    {id=26,width=165,height=300},
    {id=27,width=165,height=300},
    {id=28,width=165,height=300},
    {id=29,width=165,height=300},
    {id=30,width=165,height=300},
    {id=31,width=165,height=300},
    {id=32,width=165,height=300},
    {id=33,width=165,height=300},
    {id=34,width=165,height=300},
    {id=35,width=165,height=300},
    {id=36,width=165,height=300},
    {id=37,width=165,height=300},
    {id=38,width=165,height=300},
    {id=39,width=165,height=300},
    {id=40,width=165,height=300},
    {id=41,width=165,height=300},
    {id=42,width=165,height=300},
    {id=43,width=165,height=300},
    {id=44,width=165,height=300},
    {id=45,width=165,height=300},
    {id=46,width=165,height=300},
    {id=47,width=165,height=300},
    {id=48,width=165,height=300},
    {id=49,width=165,height=300},
    {id=50,width=165,height=300},
    {id=51,width=165,height=300},
    {id=52,width=165,height=300},
    {id=53,width=165,height=300},
    {id=54,width=165,height=300},
    {id=55,width=165,height=300},
    {id=56,width=165,height=300},
    {id=57,width=165,height=300},
    {id=58,width=165,height=300},
    {id=59,width=165,height=300},
    {id=60,width=165,height=300},
    {id=61,width=165,height=300},
    {id=62,width=165,height=300},
    {id=63,width=165,height=300},
    {id=64,width=165,height=300},
    {id=65,width=165,height=300},
    {id=66,width=165,height=300},
    {id=67,width=165,height=300},
    {id=68,width=165,height=300},
    {id=69,width=165,height=300},
    {id=70,width=165,height=300},
    {id=71,width=165,height=300},
    {id=72,width=165,height=300},
    {id=73,width=165,height=300},
    {id=75,width=165,height=300},
    {id=76,width=165,height=300},
    {id=77,width=165,height=300},
    {id=78,width=165,height=300},
    {id=79,width=165,height=300},
    {id=80,width=165,height=300},
    {id=81,width=165,height=300},
    {id=82,width=165,height=300},
    {id=83,width=165,height=300},
    {id=84,width=165,height=300},
    {id=85,width=165,height=300},
    {id=86,width=165,height=300},
    {id=87,width=165,height=300},
    {id=88,width=165,height=300},
    {id=89,width=165,height=300},
    {id=90,width=165,height=300},
    {id=91,width=165,height=300},
    {id=92,width=165,height=300},
    {id=93,width=165,height=300},
    {id=94,width=165,height=300},
    {id=95,width=165,height=300},
    {id=96,width=165,height=300},
    {id=97,width=165,height=300},
    {id=98,width=165,height=300},
    {id=99,width=165,height=300},
    {id=100,width=165,height=300},
    {id=101,width=165,height=300},
    {id=102,width=165,height=300},
    {id=103,width=165,height=300},
    {id=104,width=165,height=300},
    {id=105,width=165,height=300},
    {id=106,width=165,height=300},
    {id=107,width=165,height=300},
    {id=108,width=165,height=300},
    {id=109,width=165,height=300},
    {id=110,width=165,height=300},
    {id=111,width=165,height=300},
    {id=112,width=165,height=300},
    {id=113,width=165,height=300},
    {id=114,width=165,height=300},
    {id=115,width=165,height=300},
    {id=116,width=165,height=300},
    {id=117,width=165,height=300},
    {id=118,width=165,height=300},
    {id=119,width=165,height=300},
    {id=120,width=165,height=300},
    {id=121,width=165,height=300},
    {id=122,width=165,height=300},
    {id=123,width=165,height=300},
    {id=124,width=165,height=300},
    {id=125,width=165,height=300},
    {id=126,width=165,height=300},
    {id=127,width=165,height=300},
    {id=128,width=165,height=300},
    {id=129,width=165,height=300},
    {id=130,width=165,height=300},
    {id=131,width=165,height=300},
    {id=132,width=165,height=300},
    {id=133,width=165,height=300},
    {id=134,width=165,height=300},
    {id=135,width=165,height=300},
    {id=136,width=165,height=300},
    {id=137,width=165,height=300},
    {id=138,width=165,height=300},
    {id=139,width=165,height=300},
    {id=140,width=165,height=300},
    {id=141,width=165,height=300},
    {id=142,width=165,height=300},
    {id=143,width=165,height=300},
    {id=144,width=165,height=300},
    {id=145,width=165,height=300},
    {id=146,width=165,height=300},
    {id=147,width=165,height=300},
    {id=148,width=165,height=300},
    {id=149,width=165,height=300},
    {id=150,width=165,height=300},
    {id=151,width=165,height=300},
    {id=152,width=165,height=300},
    {id=153,width=165,height=300},
    {id=154,width=165,height=300},
    {id=155,width=165,height=300},
    {id=156,width=165,height=300},
    {id=157,width=165,height=300},
    {id=158,width=165,height=300},
    {id=159,width=165,height=300},
    {id=160,width=165,height=300},
    {id=161,width=165,height=300},
    {id=162,width=165,height=300},
    {id=163,width=165,height=300},
    {id=164,width=165,height=300},
    {id=165,width=165,height=300},
    {id=166,width=165,height=300},
    {id=167,width=165,height=300},
    {id=168,width=165,height=300},
    {id=169,width=165,height=300},
    {id=170,width=165,height=300},
    {id=171,width=165,height=300},
    {id=172,width=165,height=300},
    {id=173,width=165,height=300},
    {id=174,width=165,height=300},
    {id=175,width=165,height=300},
    {id=176,width=165,height=300},
    {id=177,width=165,height=300},
    {id=178,width=165,height=300},
    {id=179,width=165,height=300},
    {id=180,width=165,height=300},
    {id=181,width=165,height=300},
    {id=182,width=165,height=300},
    {id=183,width=165,height=300},
    {id=184,width=165,height=300},
    {id=185,width=165,height=300},
    {id=186,width=165,height=300},
    {id=187,width=165,height=300},
    {id=188,width=165,height=300},
    {id=189,width=165,height=300},
    {id=190,width=165,height=300},
    {id=191,width=165,height=300},
    {id=192,width=165,height=300},
    {id=193,width=165,height=300},
    {id=194,width=165,height=300},
    {id=195,width=165,height=300},
    {id=196,width=165,height=300},
    {id=197,width=165,height=300},
    {id=198,width=165,height=300},
    {id=199,width=165,height=300},
    {id=200,width=165,height=300},
    {id=201,width=165,height=300},
    {id=202,width=165,height=300},
    {id=203,width=165,height=300},
    {id=204,width=165,height=300},
    {id=205,width=165,height=300},
    {id=206,width=165,height=300},
    {id=207,width=165,height=300},
    {id=208,width=165,height=300},
    {id=209,width=165,height=300},
    {id=210,width=165,height=300},
    {id=211,width=165,height=300},
    {id=212,width=165,height=300},
    {id=213,width=165,height=300},
    {id=214,width=165,height=300},
    {id=215,width=165,height=300},
    {id=216,width=165,height=300},
    {id=217,width=165,height=300},
    {id=218,width=165,height=300},
    {id=219,width=165,height=300},
    {id=220,width=165,height=300},
    {id=221,width=165,height=300},
    {id=222,width=165,height=300},
    {id=223,width=165,height=300},
    {id=224,width=165,height=300},
    {id=225,width=165,height=300},
    {id=226,width=165,height=300},
    {id=227,width=165,height=300},
    {id=228,width=165,height=300},
    {id=229,width=165,height=300},
    {id=230,width=165,height=300},
    {id=231,width=165,height=300},
    {id=232,width=165,height=300},
    {id=233,width=165,height=300},
    {id=234,width=165,height=300},
    {id=235,width=165,height=300},
    {id=236,width=165,height=300},
    {id=237,width=165,height=300},
    {id=238,width=165,height=300},
    {id=239,width=165,height=300},
    {id=240,width=165,height=300},
    {id=241,width=165,height=300},
    {id=242,width=165,height=300},
    {id=243,width=165,height=300},
    {id=244,width=165,height=300},
    {id=245,width=165,height=300},
    {id=246,width=165,height=300},
    {id=247,width=165,height=300},
    {id=248,width=165,height=300},
    {id=249,width=165,height=300},
    {id=250,width=165,height=300},
    {id=251,width=165,height=300},
    {id=252,width=165,height=300},
    {id=253,width=165,height=300},
    {id=254,width=165,height=300},
    {id=255,width=165,height=300},
    {id=256,width=165,height=300},
    {id=257,width=165,height=300},
    {id=258,width=165,height=300},
    {id=259,width=165,height=300},
    {id=260,width=165,height=300},
    {id=261,width=165,height=300},
    {id=262,width=165,height=300},
    {id=263,width=165,height=300},
    {id=264,width=165,height=300},
    {id=268,width=165,height=300},
    {id=269,width=165,height=300},
    {id=270,width=165,height=300},
    {id=271,width=165,height=300},
    {id=272,width=165,height=300},
    {id=273,width=165,height=300},
    {id=289,width=165,height=300},
    {id=290,width=165,height=300},
    {id=291,width=165,height=300},
    {id=292,width=165,height=300},
    {id=293,width=165,height=300},
    {id=294,width=165,height=300},
    {id=295,width=165,height=300},
    {id=296,width=165,height=300},
    {id=297,width=165,height=300},
    {id=298,width=165,height=300},
    {id=299,width=165,height=300},
}

end

package.preload['src.core.Timer'] = function()
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

end

package.preload['src.core.Updates'] = function()
local Config=require('src.core.Config')
local R=require('src.core.Rules')
local Http=require('src.utils.AsyncHttpRequest')
local json=require('dkjson')
local ffi=require('ffi')
local U={version='1.0.0-test.16',runtime=5,status='Menu update check pending',skins_status='Using bundled alliance skins',busy=false,skins_busy=false}
local base='https://garries420.github.io/LeoneMenu/'
local menu_url=base..'LeoneMenu.lua'
local cache='config/Leone Menu/alliance-skins.html'
local initial={132,137,209,212,230,236,107,195,270,269,271,106,293,0,68,200,62,221,229,214,127,124,24,164,202,66,234,235,261,272,43,91,2,291,93,101,233,126,211}
U.alliance={version=2,skins=initial}
function U.sha256(text)
    pcall(ffi.cdef,[[
        int __stdcall CryptAcquireContextA(uintptr_t*,const char*,const char*,unsigned long,unsigned long);
        int __stdcall CryptCreateHash(uintptr_t,unsigned int,uintptr_t,unsigned long,uintptr_t*);
        int __stdcall CryptHashData(uintptr_t,const unsigned char*,unsigned long,unsigned long);
        int __stdcall CryptGetHashParam(uintptr_t,unsigned long,unsigned char*,unsigned long*,unsigned long);
        int __stdcall CryptDestroyHash(uintptr_t);
        int __stdcall CryptReleaseContext(uintptr_t,unsigned long);
    ]])
    local a=ffi.load('advapi32');local ctx=ffi.new('uintptr_t[1]');local hash=ffi.new('uintptr_t[1]')
    if a.CryptAcquireContextA(ctx,nil,nil,24,0xF0000000)==0 then return nil end
    if a.CryptCreateHash(ctx[0],0x800c,0,0,hash)==0 then a.CryptReleaseContext(ctx[0],0);return nil end
    local digest=ffi.new('unsigned char[32]');local size=ffi.new('unsigned long[1]',32)
    local ok=a.CryptHashData(hash[0],ffi.cast('const unsigned char*',text),#text,0)~=0 and a.CryptGetHashParam(hash[0],2,digest,size,0)~=0
    a.CryptDestroyHash(hash[0]);a.CryptReleaseContext(ctx[0],0)
    if not ok then return nil end
    local out={};for i=0,31 do out[#out+1]=string.format('%02x',digest[i]) end
    return table.concat(out)
end
function U.is_alliance(id) for _,v in ipairs(U.alliance.skins) do if v==id then return true end end return false end
function U.check_skins(manual)
    if U.skins_busy then return end
    U.skins_busy=true
    U.skins_status='Checking alliance skins...'
    Http:new('GET',base..'alliance-skins.html',nil,20):then_(function(res)
        local parsed=res.status_code==200 and R.alliance(res.text)
        if not parsed then
            U.skins_status='Using saved alliance skins (revision '..U.alliance.version..')'
        elseif parsed.version>U.alliance.version then
            local ok=Config.write(cache,res.text)
            if ok then U.alliance=parsed;U.skins_status='Alliance skins updated to revision '..parsed.version
            else U.skins_status='Could not save skin update; previous list retained' end
        else U.skins_status='Alliance skins are current (revision '..U.alliance.version..')' end
        if manual then msg(U.skins_status) end
    end):catch(function() U.skins_status='Using saved alliance skins (revision '..U.alliance.version..')' end):finally(function() U.skins_busy=false end)
end
local function install(manifest)
    U.status='Downloading version '..manifest.version
    Http:new('GET',menu_url,nil,30):then_(function(res)
        if res.status_code~=200 or #res.text<1000 or U.sha256(res.text)~=manifest.sha256:lower() then U.status='Update verification failed; current menu kept';return end
        local compiled=loadstring(res.text,'@LeoneMenu-update')
        if not compiled or not res.text:find('LEONE_MENU_BUNDLE',1,true) then U.status='Invalid update; current menu kept';return end
        local target=thisScript().path
        local old=Config.read(target)
        if not old then U.status='Could not read current script';return end
        local ok=Config.write('config/Leone Menu/LeoneMenu.previous.lua',old)
        if not ok then U.status='Could not save rollback copy';return end
        ok=Config.write(target,res.text)
        if not ok then U.status='Could not replace script; current menu kept';return end
        U.status='Installed Leone Menu '..manifest.version
        msg('Updated Leone Menu to {1E3348}'..manifest.version..'{FFFFFF}. Reloading...')
        require('src.components.Home').reload_requested=true
    end):catch(function() U.status='Update download failed; current menu kept' end):finally(function() U.busy=false end)
end
function U.check_menu(manual)
    if U.busy then return end
    U.busy=true;U.status='Checking for updates...'
    Http:new('GET',base..'leone-update.json',nil,20):then_(function(res)
        local m=res.status_code==200 and json.decode(res.text)
        if res.status_code==404 then
            U.status='Menu updates are waiting for the GitHub feed';U.busy=false
        elseif type(m)~='table' or type(m.version)~='string' or type(m.sha256)~='string'
            or not m.sha256:match('^%x+$') or #m.sha256~=64 or m.url~=menu_url then
            U.status='Could not verify the update feed; keeping '..U.version;U.busy=false
        elseif not R.newer(m.version,U.version) then U.status='Leone Menu is up to date ('..U.version..')';U.busy=false
        elseif m.runtime~=U.runtime then U.status='New package required: '..m.version;U.busy=false
        else install(m) end
        if manual then msg(U.status) end
    end):catch(function() U.status='Could not check updates; menu works offline';U.busy=false end)
end
function U.start()
    local saved=Config.read(cache)
    local parsed=saved and R.alliance(saved)
    if parsed and parsed.version>=U.alliance.version then U.alliance=parsed end
    U.check_menu(false);U.check_skins(false)
    lua_thread.create(function() while true do wait(3600000);U.check_skins(false) end end)
end
return U

end

package.preload['src.main'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\main.lua

__luapack_timestamp = __luapack_timestamp

script_name("Leone Menu")
script_version("1.0.0-test.16")
script_authors("Kev", "Futurestunt", "Garry")

local bit = require("bit")
local fa = require("fAwesome7")
local ffi = require("ffi")
local imgui = require("upmimgui")
local sampev = require("samp.events")
imgui.SetDpiScalingMode(3)

require("src.ui.Widgets")
local shared = require("src.shared")

local SCRIPT_TAG = '{1E3348}[Leone Menu] {FFFFFF}'
local SCRIPT_COLOR = 0xFF1E3348

local CAMERA_MODES = {
    SNIPER = 0x7,
    ROCKETLAUNCHER = 0x8,
    ROCKETLAUNCHER_HS = 0x33,
    AIMWEAPON = 0x35,
    CAMERA = 0x2E
}

local CURSOR_SHOWING = 0x00000001

ffi.cdef [[
    typedef struct {
        long x;
        long y;
    } POINT;

    typedef struct {
        unsigned int cbSize;
        unsigned int flags;
        void* hCursor;
        POINT ptScreenPos;
    } CURSORINFO;

    int GetCursorInfo(CURSORINFO* pci);
]]

local registered_commands = {}
local _commands_state = {
    is_cmd_self_sent = {},
    is_script_sending_command = {},
}
local _is_loading_interior = false

string.trim = string.trim or function(s)
    return s:match("^%s*(.-)%s*$")
end

function table.contains(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end

    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

function table.remove_value(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end

    for i = 1, #tbl do
        if tbl[i] == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function is_within_distance_3d(x1, y1, z1, x2, y2, z2, max_distance)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= (max_distance * max_distance)
end

function is_cursor_active()

    local ci = ffi.new("CURSORINFO[1]")
    ci[0].cbSize = ffi.sizeof(ci[0])

    local result = ffi.C.GetCursorInfo(ci)
    if result == 0 then
        return false
    end

    return bit.band(ci[0].flags, CURSOR_SHOWING) ~= 0 or sampIsCursorActive()
end

function pass_render_checks()
    return sampGetGamestate() == 3 and
        not (sampGetChatDisplayMode() == 0 or
            sampIsScoreboardOpen() or
            isSampfuncsConsoleActive() or
            isPauseMenuActive())
end

function is_aiming(scoped_only)
    local camera_mode_id = readMemory(0xB6F1A8, 1, false)

    local is_scope_mode = camera_mode_id == CAMERA_MODES.SNIPER or
        camera_mode_id == CAMERA_MODES.ROCKETLAUNCHER or
        camera_mode_id == CAMERA_MODES.ROCKETLAUNCHER_HS

    local is_aim_mode = is_scope_mode or
        camera_mode_id == CAMERA_MODES.AIMWEAPON or
        camera_mode_id == CAMERA_MODES.CAMERA

    if scoped_only then
        return is_scope_mode
    end

    return is_aim_mode
end

function msg(...)
    local values={...};for i,v in ipairs(values) do values[i]=tostring(v) end
    local message=table.concat(values,' ')
    message=message:gsub('{(%x%x%x%x%x%x)}',function(c)
        c=c:upper();return ({FFFFFF=true,['00FF00']=true,['6DFB6D']=true,['33CCFF']=true,['FF0000']=true,['FF4444']=true})[c] and ('{'..c..'}') or '{1E3348}'
    end)
    sampAddChatMessage(SCRIPT_TAG .. message, SCRIPT_COLOR)
end

local originalSampRegisterChatCommand = sampRegisterChatCommand

function sampRegisterChatCommand(command, callback)
    registered_commands["/" .. command] = callback
    originalSampRegisterChatCommand(command, callback)
end

function send_user_command(text)
    local cmd,args=text:match('^/(%S+)%s*(.*)$')
    local callback=cmd and registered_commands['/'..cmd:lower()]
    if callback then callback(args or '') else sampSendChat(text) end
end

function get_registered_commands()
    return registered_commands
end

function samp_send_hidden_command(command, args)
    local cmd_key = "/" .. command
    args = args or ""

    local full_cmd = args ~= "" and (cmd_key .. " " .. args) or cmd_key

    _commands_state.is_script_sending_command[cmd_key] = true
    sampSendChat(full_cmd)
end

function is_command_self_sent(command)
    local cmd_key = "/" .. command
    return _commands_state.is_cmd_self_sent[cmd_key] or false
end

local function setup_directories()
    local base_dir = getWorkingDirectory() .. '\\config'
    local sputnik_dir = base_dir .. '\\Leone Menu'

    if not doesDirectoryExist(base_dir) then
        createDirectory(base_dir)
    end
    if not doesDirectoryExist(sputnik_dir) then
        createDirectory(sputnik_dir)
    end
end

local AcceptVest = require("src.components.AcceptVest")
local AutoVest = require("src.components.AutoVest")
local Backup = require("src.components.Backup")
local Equipment = require("src.components.Equipment")
local Find = require("src.components.Find")
local Fixes = require("src.components.Fixes")
local Keybinds = require("src.components.Keybinds")
local Misc = require("src.components.Misc")
local PedCounter = require("src.components.PedCounter")
local Phone = require("src.components.Phone")
local Points = require("src.components.Points")
local Turfs = require("src.components.Turfs")

local AcceptVestOverlay = require("src.overlays.AcceptVest")
local AutoVestOverlay = require("src.overlays.AutoVest")
local BackupOverlay = require("src.overlays.Backup")
local PedCounterOverlay = require("src.overlays.PedCounter")
local PointsOverlay = require("src.overlays.Points")
local TurfsOverlay = require("src.overlays.Turfs")

local Home = require("src.components.Home")
local Extras = require("src.components.Extras")
local Capture = require("src.components.Capture")

local components = {
    { component = Home },
    { component = Extras },
    { component = Capture },
    { component = AcceptVest,    overlay = AcceptVestOverlay },
    { component = AutoVest,      overlay = AutoVestOverlay },
    { component = Backup,        overlay = BackupOverlay },
    { component = Equipment,     overlay = nil },
    { component = Find,          overlay = nil },
    { component = Fixes,         overlay = nil },
    { component = Keybinds,      overlay = nil },
    { component = Misc,          overlay = nil },
    { component = PedCounter,    overlay = PedCounterOverlay },
    { component = Phone,         overlay = nil },
    { component = Points,        overlay = PointsOverlay },
    { component = Turfs,         overlay = TurfsOverlay },
}

local function initialize_components()
    for _, pair in ipairs(components) do
        local component = pair.component
        local overlay = pair.overlay

        if component and component.register then
            local success, err = pcall(function()
                component:register()
            end)
            if not success then
                msg("Failed to initialize component:", err)
            end
        end

        if overlay and overlay.create then
            local success, err = pcall(function()
                overlay.create()
            end)
            if not success then
                msg("Failed to initialize overlay:", err)
            end
        end
    end
end

local function process_player_tick()

    if not doesCharExist(PLAYER_PED) then
        return
    end

    local x, y, z = getCharCoordinates(PLAYER_PED)
    local is_on_foot = not isCharInAnyCar(PLAYER_PED)

    shared.event_handler:process("PED_TICK", x, y, z)

    if is_on_foot then
        shared.event_handler:process("PED_TICK_ON_FOOT", x, y, z)
    else
        local vehicle_handle = storeCarCharIsInNoSave(PLAYER_PED)
        local is_driver = (getDriverOfCar(vehicle_handle) == PLAYER_PED)
        shared.event_handler:process("PED_TICK_IN_CAR", x, y, z, vehicle_handle, is_driver)
    end
end

function sampev.onServerMessage(color, text)
    return shared.event_handler:process("SERVER_MESSAGE", color, text)
end

function sampev.onEditAttachedObject(index)
    return shared.event_handler:process("EDIT_ATTACHED_OBJECT", index)
end

function sampev.onSendDialogResponse(id, button, list, input)
    return shared.event_handler:process('SEND_DIALOG_RESPONSE',id,button,list,input)
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    return shared.event_handler:process("SHOW_DIALOG", id, style, title, button1, button2, text)
end

function sampev.onShowTextDraw(id, data)

    if data.text == "~r~Objects loading..." then
        _is_loading_interior = true
    elseif data.text == "~g~Objects loaded!" then
        _is_loading_interior = false
        end

    return shared.event_handler:process("SHOW_TEXTDRAW", id, data)
end

function sampev.onToggleSelectTextDraw(state, hovercolor)
    return shared.event_handler:process("TOGGLE_SELECT_TEXTDRAW", state, hovercolor)
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
    return shared.event_handler:process("CREATE_3D_TEXT", id, color, position, distance, testLOS, attachedPlayerId,
        attachedVehicleId, text)
end

function sampev.onDisplayGameText(style, time, text)
    return shared.event_handler:process("DISPLAY_GAME_TEXT", style, time, text)
end

function sampev.onPlayerJoin(player_id, color, is_npc, nick)
    return shared.event_handler:process("PLAYER_JOIN", player_id, color, is_npc, nick)
end

function sampev.onPlayerQuit(player_id, reason)
    return shared.event_handler:process("PLAYER_QUIT", player_id, reason)
end

function sampev.onPlayerStreamIn(player_id, team, model, position, rotation, color, fighting_style)
    return shared.event_handler:process("PLAYER_STREAM_IN", player_id, team, model, position, rotation, color,
        fighting_style)
end

function sampev.onPlayerStreamOut(player_id)
    return shared.event_handler:process("PLAYER_STREAM_OUT", player_id)
end

function sampev.onSetPlayerAttachedObject(player_id, index, create, object)
    return shared.event_handler:process("SET_PLAYER_ATTACHED_OBJECT", player_id, index, create, object)
end

function sampev.onGangZoneFlash(zoneid, color)
    return shared.event_handler:process("GANG_ZONE_FLASH", zoneid, color)
end

function sampev.onGangZoneStopFlash(zoneid)
    return shared.event_handler:process("GANG_ZONE_STOP_FLASH", zoneid)
end

function sampev.onSendEnterVehicle(vehicleid, passenger)
    return shared.event_handler:process("SEND_ENTER_VEHICLE", vehicleid, passenger)
end

function sampev.onSendCommand(cmd)
    local cmd_name = cmd:match("^(%/%S*)")
    local is_script_sent = _commands_state.is_script_sending_command[cmd_name] == true

    if is_script_sent then
        _commands_state.is_cmd_self_sent[cmd_name] = false
        _commands_state.is_script_sending_command[cmd_name] = nil
    else
        _commands_state.is_cmd_self_sent[cmd_name] = true
    end

    if _is_loading_interior then
        lua_thread.create(function()

            while _is_loading_interior do
                wait(100)
            end

            if is_script_sent then
                _commands_state.is_script_sending_command[cmd_name] = true
            end

            if shared.event_handler:process("SEND_COMMAND", cmd) then
                sampSendChat(cmd)
            end
        end)
        return false
    end

    return shared.event_handler:process("SEND_COMMAND", cmd)
end

function imgui.DarkTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local c = imgui.Col

    local function rgba(r, g, b, a)
        return imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
    end

    local spacing = {
        xs = 4.0,
        sm = 8.0,
        md = 16.0,
        lg = 24.0,
        xl = 32.0
    }

    style.WindowRounding = 12.0
    style.WindowBorderSize = 0.0
    style.WindowTitleAlign = imgui.ImVec2(0.0, 0.5)
    style.WindowPadding = imgui.ImVec2(spacing.sm, spacing.sm)
    style.WindowMinSize = imgui.ImVec2(320.0, 240.0)

    style.FrameRounding = 8.0
    style.FrameBorderSize = 1.0
    style.FramePadding = imgui.ImVec2(spacing.sm, spacing.sm)
    style.ItemSpacing = imgui.ImVec2(spacing.sm, spacing.sm)
    style.ItemInnerSpacing = imgui.ImVec2(spacing.xs, spacing.xs)
    style.IndentSpacing = spacing.lg

    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 6.0

    style.GrabRounding = 8.0
    style.GrabMinSize = 14.0
    style.ChildRounding = 8.0
    style.ChildBorderSize = 1.0
    style.PopupRounding = 12.0
    style.PopupBorderSize = 1.0
    style.TabRounding = 8.0
    style.TabBorderSize = 0.0
    style.CellPadding = imgui.ImVec2(spacing.sm, spacing.xs)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.SelectableTextAlign = imgui.ImVec2(0.0, 0.5)

    local surface = rgba(16, 16, 20, 255)
    local surface_variant = rgba(28, 27, 31, 128)
    local surface_container = rgba(25, 25, 29, 140)
    local surface_bright = rgba(40, 40, 44, 160)

    local primary = rgba(30, 51, 72, 255)
    local primary_container = rgba(30, 51, 72, 255)

    local secondary = rgba(30, 51, 72, 255)

    local outline = rgba(147, 143, 153, 76)
    local outline_variant = rgba(73, 69, 79, 102)

    local on_surface = rgba(230, 225, 229, 255)
    local on_surface_variant = rgba(202, 196, 208, 255)
    local on_surface_disabled = rgba(202, 196, 208, 97)

    local primary_hover = rgba(30, 51, 72, 210)
    local primary_pressed = rgba(30, 51, 72, 170)
    local surface_hover = rgba(230, 225, 229, 15)
    local surface_pressed = rgba(230, 225, 229, 25)

    style.Colors[c.Text] = on_surface
    style.Colors[c.TextDisabled] = on_surface_disabled
    style.Colors[c.WindowBg] = surface
    style.Colors[c.ChildBg] = surface_variant
    style.Colors[c.PopupBg] = surface
    style.Colors[c.Border] = outline
    style.Colors[c.BorderShadow] = rgba(0, 0, 0, 0)

    style.Colors[c.FrameBg] = surface_variant
    style.Colors[c.FrameBgHovered] = primary_hover
    style.Colors[c.FrameBgActive] = primary_container

    style.Colors[c.TitleBg] = surface
    style.Colors[c.TitleBgActive] = surface_container
    style.Colors[c.TitleBgCollapsed] = surface_variant

    style.Colors[c.MenuBarBg] = surface_variant

    style.Colors[c.ScrollbarBg] = surface
    style.Colors[c.ScrollbarGrab] = surface_bright
    style.Colors[c.ScrollbarGrabHovered] = outline
    style.Colors[c.ScrollbarGrabActive] = on_surface_variant

    style.Colors[c.CheckMark] = primary
    style.Colors[c.SliderGrab] = primary
    style.Colors[c.SliderGrabActive] = primary_pressed

    style.Colors[c.Button] = primary_container
    style.Colors[c.ButtonHovered] = primary_hover
    style.Colors[c.ButtonActive] = primary_pressed

    style.Colors[c.Header] = surface_container
    style.Colors[c.HeaderHovered] = primary_hover
    style.Colors[c.HeaderActive] = primary_pressed

    style.Colors[c.Separator] = outline_variant
    style.Colors[c.SeparatorHovered] = primary_hover
    style.Colors[c.SeparatorActive] = primary

    style.Colors[c.ResizeGrip] = rgba(0, 0, 0, 0)
    style.Colors[c.ResizeGripHovered] = primary_hover
    style.Colors[c.ResizeGripActive] = primary

    style.Colors[c.Tab] = surface_variant
    style.Colors[c.TabHovered] = surface_hover
    style.Colors[c.TabSelected] = primary_container
    style.Colors[c.TabSelectedOverline] = primary
    style.Colors[c.TabDimmed] = surface_variant
    style.Colors[c.TabDimmedSelected] = surface_container

    style.Colors[c.PlotLines] = secondary
    style.Colors[c.PlotLinesHovered] = primary
    style.Colors[c.PlotHistogram] = primary
    style.Colors[c.PlotHistogramHovered] = primary_hover

    style.Colors[c.TableHeaderBg] = surface_container
    style.Colors[c.TableBorderStrong] = outline
    style.Colors[c.TableBorderLight] = outline_variant
    style.Colors[c.TableRowBg] = rgba(0, 0, 0, 0)
    style.Colors[c.TableRowBgAlt] = surface_hover

    style.Colors[c.TextSelectedBg] = primary_pressed
    style.Colors[c.DragDropTarget] = primary_hover

    style.Colors[c.NavCursor] = primary
    style.Colors[c.NavWindowingHighlight] = primary_hover
    style.Colors[c.NavWindowingDimBg] = rgba(0, 0, 0, 128)
    style.Colors[c.ModalWindowDimBg] = rgba(0, 0, 0, 102)
end

imgui.OnInitialize(function()

    local font = Misc:get_config().font
    if font.path == "" then
        font.path = getFolderPath(0x14) .. "\\calibri.ttf"
    else

        if not doesFileExist(font.path) then
            font.path = getFolderPath(0x14) .. "\\calibri.ttf"
        end
    end

    local reference_height = 1440.0
    local res_x, res_y = getScreenResolution()
    local font_size = 18.0 * (res_y / reference_height)

    font_size = math.max(12, math.min(font_size, 18))

    imgui.GetIO().IniFilename = nil
    imgui.DarkTheme()

    imgui.GetIO().Fonts:Clear()
    imgui.GetIO().FontDefault = imgui.GetIO().Fonts:AddFontFromFileTTF(font.path, font_size)

    local icon_config = imgui.ImFontConfig()
    icon_config.MergeMode = true
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), font_size, icon_config)
end)

function save_config()
    for _, pair in ipairs(components) do
        local component = pair.component

        if component and component.save_config then
            local success, err = pcall(function()
                component:save_config()
            end)
            if not success then
                print("Failed to save component config:", err)
            end
        end
    end
end

function main()
    while not isSampAvailable() do
        wait(0)
    end

    setup_directories()
    initialize_components()
    require("src.ui.Dialogs").start()

    shared.event_handler:process("onScriptInit")

    require("src.core.Updates").start()
    Extras:loaded()
    msg("Leone Menu loaded. Use {1E3348}/leone{FFFFFF}.")

    local last_save=os.time()
    while true do
        if Home.reload_requested then
            print('Leone Menu reload requested. Closing the menu.')
            require('src.ui.MainWindow'):hide()
            wait(0) -- Let the render and input callbacks finish before teardown.
            imgui.ShutdownRenderer()
            print('Renderer closed. Reloading Leone Menu.')
            thisScript():reload()
            return
        end
        if os.time()-last_save>=30 then save_config();last_save=os.time() end
        shared.hotkey_manager:update()
        process_player_tick()
        wait(0)
    end
end

end

package.preload['src.overlays.AcceptVest'] = function()
local C=require('src.components.AcceptVest')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('vesting') or (cfg.display[0] and C:get_pending_offer()~=nil) end,function(self)
        local p=C:get_pending_offer()
        if not p and Realign:is_preview('vesting') then p={name='Preview_Player',id=42,price=200} end
        if not p then return end
        local id=p.id and tostring(p.id) or '?'
        self:TextRGB(string.format('{FFFFFF}%s Offered by: {5CCCE6}%s (%s) [$%d]',fa('SHIELD'),p.name:gsub('_',' '),id,p.price))
    end)
    overlay.prepare_layout=Layout.position_vest
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('vest_by',overlay)
end
return {create=create}

end

package.preload['src.overlays.AutoVest'] = function()
local C=require('src.components.AutoVest')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local function cooldown_seconds()
        local seconds=C:get_cooldown_remaining()
        if seconds==0 and Realign:is_preview('vesting') then return 3 end
        return seconds
    end
    local overlay=Overlay.new(cfg,function() return Realign:is_preview('vesting') or (cfg.display[0] and C:get_pending_offer()~=nil) end,function(self)
        local p=C:get_pending_offer()
        if not p and Realign:is_preview('vesting') then p={name='Preview_Player',id=21,price=200} end
        if not p then return end
        local id=p.id and tostring(p.id) or '?'
        self:TextRGB(string.format('{FFFFFF}%s Offered to: {5CCCE6}%s (%s) [$%d]',fa('SHIELD'),p.name:gsub('_',' '),id,p.price))
    end)
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('vest_to',overlay)

    local cooldown=Overlay.new(cfg,function()
        return (cfg.display[0] or Realign:is_preview('vesting')) and cooldown_seconds()>0
    end,function(self)
        local seconds=cooldown_seconds()
        if seconds>0 then self:TextRGB(('{FFFFFF}%s CD: {28DC40}%ds'):format(fa('CLOCK'),seconds)) end
    end)
    cooldown.prepare_layout=Layout.position_vest_cooldown
    cooldown.allowed_colors={['28DC40']=true}
    Layout.bind('vest_cooldown',cooldown)
end
return {create=create}

end

package.preload['src.overlays.Backup'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\overlays\Backup.lua

local bit = require("bit")
local Backup = require("src.components.Backup")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")

local function create()
    local cfg = Backup:get_overlay_config()

    local overlay=Overlay.new(
        cfg,
        function()

            if not cfg.display[0] then
                return false
            end

            if Player:is_on_admin_duty() then
                return false
            end

            return true
        end,
        function(self)
            local backup_requests = {}

            for player_id = 0, sampGetMaxPlayerId(false) do
                if sampIsPlayerConnected(player_id) then
                    if Backup:is_requesting(player_id) then
                        table.insert(backup_requests, player_id)
                    end
                end
            end

            if #backup_requests == 0 then
                self:TextRGB("No backups active")
                return
            end

            for _, player_id in ipairs(backup_requests) do
                local name = sampGetPlayerNickname(player_id)
                self:TextRGB(string.format("{FFFF00}%s (%d)", name, player_id))
            end
        end
    )
    overlay.allowed_colors={["FFFF00"]=true}
end

return {
    create = create
}

end

package.preload['src.overlays.PedCounter'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\overlays\PedCounter.lua

local Overlay = require("src.ui.Overlay")
local PedCounter = require("src.components.PedCounter")

local function create()
    local cfg = PedCounter:get_overlay_config()

    Overlay.new(
        cfg,
        function()
            if not cfg.display[0] then
                return false
            end

            if not cfg.display_outside_interiors[0] and getActiveInterior() == 0 then
                return false
            end

            return true
        end,
        function(self)
            self:TextRGB("{1E3348}PEDS: {FFFFFF}" .. PedCounter:get_active_slots())
        end
    )
end

return {
    create = create
}

end

package.preload['src.overlays.Points'] = function()
-- Appearance change only: Sputnik's minute values and render-time refresh are retained.
local C=require('src.components.Points')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local active=C:get_active_point()
    local function visible()return ((not active.refresh_timer:is_paused() and cfg.display[0]) or (cfg.display_next_information[0] and C:get_next_point()~=nil)) end
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('capture') or visible() end,function(self)
        if Realign:is_preview('capture') and not visible()then
            self:TextRGB(string.format('{FFFFFF}%s Point Capper: {5CCCE6}Preview Family {FFFFFF}| Estimated Time Left: {5CCCE6}1 minute',fa('SHIELD')))
            return
        end
        if not active.refresh_timer:is_paused() and cfg.display[0] then
            if active.refresh_timer:is_ready() then
                active.refresh_timer:trigger()
                samp_send_hidden_command('pointinfo')
            end
            local minutes=active.time_left
            local unit=minutes==1 and 'minute' or 'minutes'
            self:TextRGB(string.format('{FFFFFF}%s Point Capper: {5CCCE6}%s {FFFFFF}| Estimated Time Left: {5CCCE6}%d %s',fa('SHIELD'),require('src.core.Rules').strip(active.captured_by),minutes,unit))
        elseif cfg.display_next_information[0] then
            local name=C:get_next_point()
            local data=name and C:get_point_data(name)
            if data then self:TextRGB(string.format('{FFFFFF}%s %s | {5CCCE6}%s {FFFFFF}| %s {5CCCE6}%d hours',fa('LOCATION_DOT'),name,require('src.core.Rules').strip(data.owner),fa('CLOCK'),data.hours)) end
        end
    end)
    overlay.prepare_layout=Layout.position_point
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('point',overlay)
end
return {create=create}

end

package.preload['src.overlays.Turfs'] = function()
-- Appearance change only: Sputnik's minute values and render-time refresh are retained.
local C=require('src.components.Turfs')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local Rules=require('src.core.Rules')
local function create()
    local cfg=C:get_overlay_config()
    local active=C:get_active_turf()
    local function visible()return (getActiveInterior()==0 or cfg.display_inside_interiors[0]) and ((not active.refresh_timer:is_paused() and cfg.display_war_information[0]) or (cfg.display_next_information[0] and C:get_next_turf()~=nil)) end
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('capture') or visible() end,function(self)
        if Realign:is_preview('capture') and not visible()then
            self:TextRGB(string.format('{FFFFFF}%s Turf Capper: {5CCCE6}Preview Family (Pershing Sq.) {FFFFFF}| Time Left: {5CCCE6}7 minutes',fa('SHIELD')))
            return
        end
        if not active.refresh_timer:is_paused() and cfg.display_war_information[0] then
            if active.refresh_timer:is_ready() then
                active.refresh_timer:trigger()
                samp_send_hidden_command('turfinfo')
            end
            local minutes=active.time_left
            local unit=minutes==1 and 'minute' or 'minutes'
            local name=Rules.short_turf(active.name)
            local location=name~='' and (' ('..name..')') or ''
            self:TextRGB(string.format('{FFFFFF}%s Turf Capper: {5CCCE6}%s%s {FFFFFF}| Time Left: {5CCCE6}%d %s',fa('SHIELD'),Rules.strip(active.captured_by),location,minutes,unit))
        elseif cfg.display_next_information[0] then
            local name=C:get_next_turf()
            local data=name and C:get_turf_data(name)
            if data then self:TextRGB(string.format('{FFFFFF}%s %s | {5CCCE6}%s {FFFFFF}| %s {5CCCE6}%d hours',fa('LOCATION_DOT'),name,require('src.core.Rules').strip(data.owner),fa('CLOCK'),data.hours)) end
        end
    end)
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('turf',overlay)
end
return {create=create}

end

package.preload['src.shared'] = function()
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

end

package.preload['src.ui.AllianceEditor'] = function()
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local R=require('src.core.Rules')
local Import=require('src.core.GangImport')
local Picker=require('src.ui.SkinPicker')
local E={name='',hex='1E3348',skins=''}
function E:show(groups,on_save)
    self.groups=groups;self.on_save=on_save;self.open=true
    self.name='';self.hex='1E3348';self.skins='';self.index=nil;self.error=nil
end
local function color(hex)
    local n=tonumber(hex,16) or 0
    return imgui.ImVec4(math.floor(n/65536)/255,math.floor(n/256)%256/255,n%256/255,1)
end
function E:render()
    if self.open then imgui.OpenPopup('Add gang');self.open=false end
    local display=imgui.GetIO().DisplaySize
    local width=math.min(460,display.x-32)
    local height=math.min(740,display.y-48)
    imgui.SetNextWindowSize(imgui.ImVec2(width,height),imgui.Cond.Always)
    if not imgui.BeginPopupModal('Add gang',nil,imgui.WindowFlags.NoResize+imgui.WindowFlags.NoScrollbar+imgui.WindowFlags.NoScrollWithMouse)then return end
    local avail=imgui.GetContentRegionAvail()
    imgui.BeginChild('gang_editor_body',imgui.ImVec2(0,math.max(80,avail.y-58)),false)
    if imgui.AnimButton(fa('SHIRT')..' Skins') then
        Picker:show(R.skins(self.skins) or {},function(ids)self.skins=table.concat(ids,', ')end)
    end
    if imgui.IsItemHovered()then imgui.SetTooltip('Choose skins by clicking their images.')end
    imgui.SameLine()
    if imgui.AnimButton('Auto import')then Import:toggle()end
    if imgui.IsItemHovered()then imgui.SetTooltip('Displays every available gangs from /gangs. pick one and it auto chooses its name and color code')end
    if Import.visible then
        if Import.importing then imgui.TextDisabled('Importing gangs...')end
        for i,g in ipairs(Import.rows)do
            imgui.PushStyleColor(imgui.Col.Text,color(g.hex))
            if imgui.Selectable(g.name..'##import'..i,false,imgui.SelectableFlags.NoAutoClosePopups)then
                self.name=g.name;self.hex=g.hex;self.error=nil
            end
            imgui.PopStyleColor()
        end
        if not Import.importing and #Import.rows==0 then imgui.TextDisabled('No gang list yet. Try Auto import again.')end
        imgui.Separator()
    end
    local field_width=imgui.GetContentRegionAvail().x
    imgui.Text('Name');self.name=H.input('##gang_name',self.name,'Gang name',field_width,40)
    imgui.Text('Hex color code');self.hex=H.input('##gang_hex',self.hex,'1E3348',field_width-44,6)
    imgui.SameLine();imgui.ColorButton('##color_preview',color(self.hex))
    imgui.Text('Skins (ID)');self.skins=H.input('##gang_skins',self.skins,'1, 2, 3, 10, 11, 22, 35',field_width,2048)
    if imgui.IsItemHovered()then imgui.SetTooltip('Format: 1, 2, 3, 10, 11, 22, 35')end
    if self.error then imgui.TextWrapped(self.error)end
    if #self.groups>0 then
        imgui.Separator();imgui.Text('Saved groups')
        for i,g in ipairs(self.groups)do
            imgui.PushID(i)
            if imgui.AnimButton(fa('TRASH')..'##remove')then
                table.remove(self.groups,i);self.index=nil;self.on_save()
            else
                imgui.SameLine()
                if imgui.Selectable(g.name,false,imgui.SelectableFlags.NoAutoClosePopups)then
                    self.name=g.name;self.hex=g.hex;self.skins=table.concat(g.skins,', ');self.index=i;self.error=nil
                end
            end
            imgui.PopID()
        end
    end
    imgui.EndChild()
    imgui.Separator()
    local button_width=math.min(150,(imgui.GetContentRegionAvail().x-12)/2)
    if imgui.AnimButton('Save',imgui.ImVec2(button_width,38))then
        local ids=R.skins(self.skins)
        if R.trim(self.name)=='' or not self.hex:match('^%x%x%x%x%x%x$') or not ids then
            self.error='Enter a name, six HEX digits and valid skin IDs.'
        else
            local g={name=R.trim(self.name),hex=self.hex:upper(),skins=ids}
            self.groups[self.index or (#self.groups+1)]=g;self.on_save();imgui.CloseCurrentPopup()
        end
    end
    imgui.SameLine();if imgui.AnimButton('Cancel',imgui.ImVec2(button_width,38))then imgui.CloseCurrentPopup()end
    Picker:render()
    imgui.EndPopup()
end
return E

end

package.preload['src.ui.CaptureLayout'] = function()
-- Shared screen-space anchor; spacing remains four pixels at any resolution.
local L={}
function L.bind(kind,overlay) L[kind]=overlay end
function L.position_point()
    if not L.turf or not L.point then return end
    local imgui=require('upmimgui')
    local height=imgui.GetIO().DisplaySize.y
    if height<=0 then return end
    local anchor=L.turf.config
    local cfg=L.point.config
    local offset=0
    if L.turf.condition() then
        offset=(L.turf.last_height or (anchor.font_size[0]+anchor.padding[0]*2+2))+4
    end
    cfg.pos.x[0]=anchor.pos.x[0]
    cfg.pos.y[0]=anchor.pos.y[0]+offset/height
end
local function row_spacing(overlay)
    if not overlay or not overlay.condition() then return 0 end
    local cfg=overlay.config
    return (overlay.last_height or (cfg.font_size[0]+cfg.padding[0]*2+2))+4
end

function L.position_vest()
    if L.vest_to then return L.vest_to.config.pos,row_spacing(L.vest_to) end
end

function L.position_vest_cooldown()
    local cooldown=L.vest_cooldown
    local cfg=cooldown.config
    local anchor=cfg.pos
    local height=require('upmimgui').GetIO().DisplaySize.y
    local gap=row_spacing(cooldown)
    local padding_delta=cfg.padding[0]-(cfg.padding_anchor or cfg.padding[0])
    if anchor.y[0]*height-padding_delta>=gap then return anchor,-gap end

    -- At the top edge, use the space beside the first offer.
    local offer=L.vest_to.condition() and L.vest_to or L.vest_by
    if not offer or not offer.condition() then return anchor,0 end
    local width=offer.last_width or (cfg.font_size[0]*18+cfg.padding[0]*2)
    local direction=anchor.x[0]>0.5 and -1 or 1
    return anchor,0,(width+4)*direction
end
return L

end

package.preload['src.ui.Dialogs'] = function()
-- Client-only SA-MP dialogs. Never submits a locally-owned dialog to HZG.
local shared=require('src.shared')
local D={queue={},active=nil,id=32760}
function D.show(title,text,style,button,callback,required,eligible)
    D.queue[#D.queue+1]={title=title,text=text,style=style,button=button,callback=callback,required=required,eligible=eligible}
end
function D.start()
    shared.event_handler:register('SEND_DIALOG_RESPONSE',function(id) return id==D.id end,function() return false end)
    lua_thread.create(function()
        while true do
            if not D.active and #D.queue>0 and not sampIsDialogActive() then
                D.active=table.remove(D.queue,1)
                if D.active.eligible and not D.active.eligible() then D.active=nil
                else sampShowDialog(D.id,D.active.title,D.active.text,D.active.button,D.active.required and '' or 'Cancel',D.active.style) end
            elseif D.active then
                local result,button,list,input=sampHasDialogRespond(D.id)
                if result then
                    local item=D.active;D.active=nil
                    if button~=1 and item.required then table.insert(D.queue,1,item)
                    elseif button==1 and item.callback then item.callback(list,input) end
                elseif sampIsDialogActive() and sampGetCurrentDialogId()~=D.id then
                    table.insert(D.queue,1,D.active);D.active=nil
                end
            end
            wait(20)
        end
    end)
end
return D

end

package.preload['src.ui.Helpers'] = function()
local imgui=require('upmimgui')
local shared=require('src.shared')
local H={color=imgui.ImVec4(30/255,51/255,72/255,1)}
function H.toggle(label,id,value,width,tip)
    imgui.Text(label)
    if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip) end
    imgui.SameLine(width-imgui.ToggleButtonWidth())
    return imgui.ToggleButton('##'..id,value)
end
function H.bind(label,id,cfg,width)
    imgui.Text(label);imgui.SameLine(width-180)
    local keys=shared.hotkey_manager:draw_key_editor(id,imgui.ImVec2(180,0))
    if keys then cfg.keys=keys end
end
function H.position(configs,prefix)
    imgui.DrawChild('Position##'..prefix,function(width)
        imgui.Text('Overlay position on screen');imgui.SameLine(width-120)
        if imgui.AnimButton('Position##'..prefix,imgui.ImVec2(120,0)) then
            require('src.utils.ElementRealigner'):realign_element(function(x,y)
                for i,c in ipairs(configs) do c.pos.x[0]=x;c.pos.y[0]=math.min(0.97,y+(i-1)*0.035) end
            end,{preview=prefix})
        end
    end)
end
function H.open(url)
    local ffi=require('ffi')
    pcall(ffi.cdef,'void* __stdcall ShellExecuteA(void*,const char*,const char*,const char*,const char*,int);')
    ffi.load('shell32').ShellExecuteA(nil,'open',url,nil,nil,1)
end
function H.input(label,value,hint,width,len)
    return imgui.StyledInputText(label,value,hint,imgui.ImVec2(width or 250,0),len or 256)
end
return H

end

package.preload['src.ui.MainWindow'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\ui\MainWindow.lua

local fa = require("fAwesome7")
local imgui = require("upmimgui")
local vk = require("vkeys")
local Search = require("src.ui.SettingsSearch")

local WINDOW = {
    SIZE = imgui.ImVec2(85, 40),
    SIDEBAR_WIDTH = 12,
    FLAGS = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize,
}

local _main_window = {
    is_open = imgui.new.bool(false),
    pages = {},
    ordered_ids = {},
    shortcuts = {},
    current_page = nil,
    query = "",
    search_id = 0,
}

local function _rebuild_order()
    _main_window.ordered_ids = {}
    local pages = {}

    for id, data in pairs(_main_window.pages) do
        table.insert(pages, { id = id, title = data.title or "", order = data.order or (id == "phone" and 999 or 10) })
    end

    table.sort(pages, function(a, b) if a.order ~= b.order then return a.order < b.order end
        return a.title < b.title end)

    for _, p in ipairs(pages) do
        table.insert(_main_window.ordered_ids, p.id)
    end

    if not _main_window.current_page and #_main_window.ordered_ids > 0 then
        _main_window.current_page = _main_window.ordered_ids[1]
    end
end

local function _clear_search()
    if _main_window.query=='' then return end
    _main_window.query=''
    -- ImGui retains an active edit buffer by widget ID. Discard it on an external clear.
    _main_window.search_id=_main_window.search_id+1
end

local function _select_page(id,anchor)
    local page=_main_window.pages[id]
    if not page then return end
    _clear_search()
    _main_window.current_page=id
    _main_window.jump=anchor
    _main_window.jump_layout=anchor~=nil
    if anchor and page.prepare_search then page.prepare_search() end
end

local function _render_sidebar()
    local window_padding = imgui.GetStyle().WindowPadding

    imgui.BeginChild(
        "sidebar_area",
        imgui.ImVec2(imgui.ScaleValue(WINDOW.SIDEBAR_WIDTH), 0),
        false,
        imgui.WindowFlags.NoScrollbar
    )

    imgui.SetCursorPosY(window_padding.y)
    local width=imgui.ScaleValue(WINDOW.SIDEBAR_WIDTH)-window_padding.x*2
    if not _main_window.logo_tried then
        _main_window.logo_tried=true
        local ok,texture=pcall(imgui.CreateTextureFromFile,getWorkingDirectory()..'/resource/Leone Menu/leone-logo.png')
        if ok then _main_window.logo=texture end
    end
    if _main_window.logo then
        local size=width
        imgui.SetCursorPosX((imgui.ScaleValue(WINDOW.SIDEBAR_WIDTH)-size)/2)
        imgui.Image(_main_window.logo,imgui.ImVec2(size,size))
    else
        imgui.TextColored(imgui.ImVec4(30/255,51/255,72/255,1),'Leone Menu')
    end
    imgui.SetCursorPosX(window_padding.x)
    local clear_width=_main_window.query~='' and imgui.GetFrameHeight()+imgui.GetStyle().ItemSpacing.x or 0
    _main_window.query=imgui.StyledInputText('##settings_search'.._main_window.search_id,_main_window.query,'Search settings',
        imgui.ImVec2(width-clear_width,0),128)
    if clear_width>0 then
        imgui.SameLine()
        if imgui.AnimButton('x##clear_search',imgui.ImVec2(imgui.GetFrameHeight(),imgui.GetFrameHeight())) then
            _clear_search()
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Clear search') end
    end
    for _, id in ipairs(_main_window.ordered_ids) do
        local page = _main_window.pages[id]

        imgui.SetCursorPosX(window_padding.x)

        if imgui.PageButton(_main_window.current_page == id, page.icon, page.title, imgui.ScaleValue(WINDOW.SIDEBAR_WIDTH) - (window_padding.x * 2), nil, page.icon_box_color) then
            _select_page(id)
        end
    end

    imgui.EndChild()
end

local function _render_results(query)
    local results=Search.find(query,_main_window.pages)
    imgui.Heading('Search results')
    if #results==0 then
        imgui.TextDisabled('No settings match your search.')
        return
    end
    for i,result in ipairs(results) do
        imgui.PushID(i)
        imgui.TextColored(imgui.ImVec4(0.58,0.68,0.77,1),result.heading)
        for _,label in ipairs(result.items) do
            local clipped=imgui.CalcTextSize(label).x>imgui.GetContentRegionAvail().x
            if imgui.Selectable(label,false) then _select_page(result.page,result.anchor) end
            if clipped and imgui.IsItemHovered() then imgui.SetTooltip(label) end
        end
        imgui.PopID()
        imgui.Separator()
    end
end

local function _render_content()
    local query=_main_window.query:match('^%s*(.-)%s*$')
    local searching=query~=''
    local key=searching and 'settings_search' or _main_window.current_page
    imgui.BeginChild("content_area##" .. tostring(key),imgui.ImVec2(0,0),false,imgui.WindowFlags.NoBackground)
    local page = _main_window.pages[_main_window.current_page]

    if searching then
        if _main_window.previous_query~=query then imgui.SetScrollY(0) end
        _render_results(query)
    elseif page then
        if page.render_function then
            local target=_main_window.jump
            if target and not _main_window.jump_layout then
                imgui.BeforeSettingsSection=function(name)
                    if name==target then
                        imgui.SetScrollFromPosY(imgui.GetCursorPosY()-imgui.GetScrollY(),0)
                        _main_window.jump=nil
                    end
                end
            end
            page.render_function()
            imgui.BeforeSettingsSection=nil
            if _main_window.jump_layout then
                -- Auto-sized cards have their measured heights on the next frame.
                _main_window.jump_layout=false
            elseif _main_window.jump then
                imgui.SetScrollY(0)
                _main_window.jump=nil
            end
        else
            imgui.Text("No render function for: " .. page.title)
        end
    else
        imgui.Text("No content")
    end

    -- A stale active control must not leave the page unable to consume wheel input.
    local wheel=imgui.GetIO().MouseWheel
    local y=imgui.GetScrollY()
    _main_window.previous_query=searching and query or nil
    local any_popup=imgui.IsPopupOpen('',imgui.PopupFlags.AnyPopupId+imgui.PopupFlags.AnyPopupLevel)
    if wheel~=0 and not any_popup and imgui.IsWindowHovered(imgui.HoveredFlags.ChildWindows) then
        local previous=_main_window.scroll_sample
        if previous and previous.page==key and math.abs(previous.y-y)<0.1 then
            imgui.SetScrollY(math.max(0,math.min(imgui.GetScrollMaxY(),y-wheel*imgui.GetFontSize()*5)))
        end
    end
    _main_window.scroll_sample={page=key,y=y}
    imgui.EndChild()
end

local function _render_window()
    require("src.shared").hotkey_manager:flush_ui_input()
    local display = imgui.GetIO().DisplaySize

    imgui.SetNextWindowPos(imgui.ImVec2(display.x / 2, display.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(math.min(display.x-32,imgui.ScaleValue(WINDOW.SIZE.x)), math.min(display.y-32,imgui.ScaleValue(WINDOW.SIZE.y))))

    if imgui.Begin("##main_window", _main_window.is_open, WINDOW.FLAGS) then
        _render_sidebar()
        imgui.SameLine()
        _render_content()
    end
    imgui.End()
end

local function _register()
    imgui.OnFrame(function() return _main_window.is_open[0] end, _render_window)

    addEventHandler("onWindowMessage", function(msg, wparam)
        if msg == 0x0100 and wparam == vk.VK_ESCAPE and _main_window.is_open[0] then
            if _main_window.query~='' then
                _main_window.query=''
            else
                _main_window.is_open[0] = false
                save_config()
            end
            consumeWindowMessage(true, false)
        end
    end)

    addEventHandler('onScriptTerminate', function(scr)
        if scr == thisScript() then
            _main_window.is_open[0] = false
            save_config()
        end
    end)

end

local MainWindow = {}

function MainWindow:add_page(id, cfg)
    if not id or not cfg or not cfg.render_function then return false end

    cfg.title = cfg.title or "No title"
    cfg.icon = cfg.icon or fa("CIRCLE")
    cfg.icon_box_color = imgui.ImVec4(30/255,51/255,72/255,1)

    _main_window.pages[id] = cfg
    _rebuild_order()

    if cfg.shortcut then
        _main_window.shortcuts[cfg.shortcut] = id
        sampRegisterChatCommand(cfg.shortcut, function()
            _main_window.current_page = id
            _main_window.is_open[0] = true
        end)
    end

    return true
end

function MainWindow:select_page(id)
    _select_page(id)
end

function MainWindow:is_open()
    return _main_window.is_open[0]
end

function MainWindow:show(shortcut)
    if shortcut then
        local target = _main_window.shortcuts[shortcut]
        if _main_window.pages[target] then
            _select_page(target)
        end
    end
    _main_window.is_open[0] = true
end

function MainWindow:hide()
    _main_window.is_open[0] = false
    save_config()
end

_register()

return MainWindow

end

package.preload['src.ui.NotificationManager'] = function()
-- Small internal status feedback; Sputnik's removed Notifications feature is not registered.
local N={};N.__index=N
function N.new() return setmetatable({types={INFO={},OK={},ERROR={}}},N) end
function N:show(text,kind) if msg then msg(text) else print('[Leone Menu] '..text) end end
return N

end

package.preload['src.ui.Overlay'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\ui\Overlay.lua

local bit = require("bit")
local imgui = require("upmimgui")
local fa = require("fAwesome7")

local ElementRealigner = require("src.utils.ElementRealigner")

local OVERLAY_FLAGS = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize +
    imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoNav +
    imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(config, condition, render_content)
    local self = setmetatable({}, Overlay)

    self.config = config
    self.condition = condition
    self.render_content = render_content

    imgui.OnFrame(
        function() return pass_render_checks() and self.condition() end,
        function()
            -- MoonLoader can process acceptance/server events after the updater's
            -- visibility check but before D3DPresent. Re-check current state here.
            if pass_render_checks() and self.condition() then self:render() end
        end
    ).HideCursor = true

    return self
end

function Overlay.setup_overlay_defaults(display, pos_x, pos_y, font_size, padding, border_thickness, rounding, bg_render,
                                        bg_color, border_render, border_color)
    return {
        display = imgui.new.bool(display ~= false),
        pos = {
            x = imgui.new.float(pos_x or 0.5),
            y = imgui.new.float(pos_y or 0.5)
        },
        font_size = imgui.new.int(font_size or 20),
        padding = imgui.new.int(padding or 4),
        border_thickness = imgui.new.int(border_thickness or 1),
        rounding = imgui.new.int(rounding or 8),

        bg_render = imgui.new.bool(bg_render ~= false),
        bg_color = imgui.new.float[4](
            bg_color and bg_color[1] or 0,
            bg_color and bg_color[2] or 0,
            bg_color and bg_color[3] or 0,
            bg_color and bg_color[4] or 0.196
        ),

        border_render = imgui.new.bool(border_render ~= false),
        border_color = imgui.new.float[4](
            border_color and border_color[1] or 0,
            border_color and border_color[2] or 0,
            border_color and border_color[3] or 0,
            border_color and border_color[4] or 0.196
        ),
    }
end

function Overlay.render_overlay_settings(config, prefix)
    prefix = prefix or ""
    local cfg = config

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Position & Appearance##" .. prefix, function(width)
        imgui.Text("Overlay position on screen")
        imgui.SameLine(width - 100)
        if imgui.AnimButton(fa("RETWEET") .. " Position", imgui.ImVec2(100, 0)) then
            ElementRealigner:realign_element(
                function(x, y)
                    cfg.pos.x[0] = x
                    cfg.pos.y[0] = y
                end, {preview=prefix}
            )
        end

        imgui.Separator()
        imgui.Text("Draw a background")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("bg_render", cfg.bg_render)
        imgui.SameLine(width - imgui.ToggleButtonWidth() - 34 - imgui.GetStyle().ItemSpacing.x)
        imgui.ColorEdit4("##bg_color", cfg.bg_color, imgui.ColorEditFlags.NoInputs)

        imgui.Separator()
        imgui.Text("Draw a border")
        imgui.SameLine(width - imgui.ToggleButtonWidth())
        imgui.ToggleButton("border_render", cfg.border_render)
        imgui.SameLine(width - imgui.ToggleButtonWidth() - 34 - imgui.GetStyle().ItemSpacing.x)
        imgui.ColorEdit4("##border_color", cfg.border_color, imgui.ColorEditFlags.NoInputs)
    end)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.DrawChild("Style Properties##" .. prefix, function(child_width)
        local sliders = {
            { id = "##font_size", value = cfg.font_size, min = 1, max = 64, text = "Font size" },
            { id = "##padding", value = cfg.padding, min = 0, max = 64, text = "Padding" },
            { id = "##border_thickness", value = cfg.border_thickness, min = 1, max = 64, text = "Border Thickness" },
            { id = "##rounding", value = cfg.rounding, min = 0, max = 64, text = "Rounding" },
        }

        local radius = imgui.ScaleValue(4)
        local spacing = imgui.ScaleValue(10)

        local total_width = #sliders * radius * 2 + (#sliders - 1) * spacing

        local start_x = math.max(0, (child_width - total_width) / 2)
        local start_y = imgui.GetCursorPos().y

        imgui.BeginGroup()
        for i, s in ipairs(sliders) do
            imgui.SetCursorPos(imgui.ImVec2(start_x + (i - 1) * (radius * 2 + spacing), start_y))
            imgui.SemiCircularSlider(s.id, s.value, s.min, s.max, radius, " px", nil, s.text)
        end
        imgui.EndGroup()
    end)
end

function Overlay:TextOutline(text, thickness)
    local pos = imgui.GetCursorPos()
    for i = 1, thickness do
        imgui.SetCursorPos(imgui.ImVec2(pos.x + i, pos.y))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x - i, pos.y))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + i))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
        imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y - i))
        imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text)
    end
    imgui.SetCursorPos(pos)
end

function Overlay:TextRGB(text)
    local cfg = self.config
    if not cfg then return end

    local style = imgui.GetStyle()
    local current_color = style.Colors[imgui.Col.Text]

    local function explode_rgba(rgba)
        local r = bit.band(bit.rshift(rgba, 24), 0xFF)
        local g = bit.band(bit.rshift(rgba, 16), 0xFF)
        local b = bit.band(bit.rshift(rgba, 8), 0xFF)
        local a = bit.band(rgba, 0xFF)
        return r, g, b, a
    end

    text = text:gsub('{(%x%x%x%x%x%x)}',function(c)
        c=c:upper()
        if self.allowed_colors and self.allowed_colors[c] then return '{'..c..'FF}' end
        if c=='FFFFFF' or c=='00FF00' or c=='6DFB6D' or c=='FF0000' or c=='FF4444' then return '{'..c..'FF}' end
        return '{1E3348FF}'
    end)

    local pos = 1
    local first_segment = true

    for tag_start, color_hex, tag_end in text:gmatch('()%{(%x%x%x%x%x%x%x%x)%}()') do

        local segment = text:sub(pos, tag_start - 1)
        if #segment > 0 then
            if not first_segment then
                imgui.SameLine(nil, 0)
            end

            imgui.PushFont(nil, cfg.font_size[0])
            self:TextOutline(segment, 2)
            imgui.TextColored(current_color, segment)
            imgui.PopFont()

            first_segment = false
        end

        local packed_color = tonumber(color_hex, 16)
        if packed_color then
            local r, g, b, a = explode_rgba(packed_color)
            current_color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
        end

        pos = tag_end
    end

    local remaining = text:sub(pos)
    if #remaining > 0 then
        if not first_segment then
            imgui.SameLine(nil, 0)
        end

        imgui.PushFont(nil, cfg.font_size[0])
        self:TextOutline(remaining, 1)
        imgui.TextColored(current_color, remaining)
        imgui.PopFont()
    end
end

function Overlay:render()
    local cfg = self.config
    if not cfg then return end

    -- Layout may read ImGui state only here, on the selected render context.
    local anchor, offset_y, offset_x
    if self.prepare_layout then anchor,offset_y,offset_x=self.prepare_layout() end
    local display_size = imgui.GetIO().DisplaySize
    local pos = anchor or cfg.pos
    local pos_x = pos.x[0] * display_size.x
    local pos_y = pos.y[0] * display_size.y + (offset_y or 0)

    local pivot = imgui.ImVec2(0.0, 0.0)
    if pos_x > display_size.x * 0.5 then
        pivot.x = 1.0
    end

    cfg.padding_anchor=cfg.padding_anchor or cfg.padding[0]
    local delta=cfg.padding[0]-cfg.padding_anchor
    pos_x=pos_x+(offset_x or 0)+(pivot.x==1 and delta or -delta)
    pos_y=pos_y-delta
    imgui.SetNextWindowPos(imgui.ImVec2(pos_x, pos_y), imgui.Cond.Always, pivot)

    if cfg.bg_render[0] then
        imgui.PushStyleColor(imgui.Col.WindowBg,
            imgui.ImVec4(cfg.bg_color[0], cfg.bg_color[1], cfg.bg_color[2], cfg.bg_color[3]))
    else

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    end

    if cfg.border_render[0] and cfg.border_thickness[0] > 0 then
        imgui.PushStyleColor(imgui.Col.Border,
            imgui.ImVec4(cfg.border_color[0], cfg.border_color[1], cfg.border_color[2], cfg.border_color[3]))
        imgui.PushStyleVar(imgui.StyleVar.WindowBorderSize, cfg.border_thickness[0])
    else
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleVar(imgui.StyleVar.WindowBorderSize, 0)
    end

    imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(cfg.padding[0], cfg.padding[0]))
    imgui.PushStyleVar(imgui.StyleVar.WindowRounding, cfg.rounding[0])

    local window_name = "Overlay##" .. tostring(self)
    imgui.Begin(window_name, nil, OVERLAY_FLAGS)

    if self.render_content then
        self.render_content(self)
    end

    self.last_width = imgui.GetWindowWidth()
    self.last_height = imgui.GetWindowHeight()
    imgui.End()

    imgui.PopStyleVar()
    imgui.PopStyleVar()
    imgui.PopStyleVar()
    imgui.PopStyleColor()
    imgui.PopStyleColor()
end

return Overlay

end

package.preload['src.ui.SettingsSearch'] = function()
-- Search uses section names from the settings pages so results can jump to the rendered cards.
local S={}
local sections={
    {'home','Credits','Sputnik credits','Kev and Futurestunt','Garry forum and Discord'},
    {'home',false,'Reload Leone Menu','Check for updates','Alliance skins revision'},
    {'auto_vest','Auto Vest','Automatically vest nearby players - /avest','Aim and vest',
        'Command mode','Alliance skins to be vested','Add gang and Auto import /gangs',
        'Vest interval (seconds)','Offer if vest is below','Show offered-to overlay'},
    {'auto_vest','Accept Vest','Automatically accept vest offers priced at $200 - /av',
        'Accept if vest is below','Manual Accept','Manually accept vest',
        'Automatically stop accepting vest offers upon point completion','Show offered-by overlay'},
    {'auto_vest','Position##vesting','Vest overlay position'},
    {'backup','Backup','Show active backup requests','Faction backup keybind','All custom locations','Mention wanted level'},
    {'backup','Portable Radio','Show frequency in chat messages','Checks /fmotd for alliance frequency and changes freq'},
    {'backup','Position & Appearance##backup','Backup overlay position','Draw a background','Draw a border'},
    {'backup','Style Properties##backup','Font size','Padding','Border Thickness','Rounding'},
    {'blackmarket','Blackmarket','Select mode - /bms','Purchase keybind','Current Mode','Purchase gap (ms)',
        'Deagle + Health & Vest','Deagle + Sniper + Health & Vest',
        'Deagle + Spas12 + Health & Vest','Deagle + Sniper + Spas12 + Health & Vest'},
    {'find','Autofind','Find Player - /af','Cohort Player - /afco','Adjust Cooldown - /afcd','Suggested Cooldown'},
    {'find','Display##autofind','Hide Redmarker Message'},
    {'keybinds',false,'Custom command keybinds','Add a keybind'},
    {'miscellaneous','Font Selector','Change font for on-screen elements'},
    {'miscellaneous','Automatization','Automatically eject all players from vehicle when it catches fire',
        'Automatically accept $1 repair offers from players','Offer $1 repair to nearest driver or passenger',
        'Automatically retry picking a vehicle lock after a failed attempt','Spam LMB while holding a Sprunk can to quickly recover health'},
    {'miscellaneous','Beacon Resolver','Resolve player IDs when written as "B20" to their actual name instead'},
    {'miscellaneous','Frisking','Play sound when frisking a player who has a sniper rifle','Aim and frisk a player'},
    {'miscellaneous','Random',"Skips over parachute but it reappears once you're falling - /skippara",'/signcheck -> /si'},
    {'miscellaneous','Vehicles','Vehicle storage and typed slot preview - /vst /fv /vtow','Spawn/Despawn vehicle - /vst',
        'Find Vehicle - /fv','Tow vehicle - /vtow'},
    {'ped_counter','Ped Counter','Show overlay with active ped slot count','Enable overlay outside interiors'},
    {'ped_counter','Position & Appearance##ped_counter','Ped counter overlay position','Draw a background','Draw a border'},
    {'ped_counter','Style Properties##ped_counter','Font size','Padding','Border Thickness','Rounding'},
    {'capture','Turfs','Show upcoming turf war info','Show active turf war info','Enable overlay inside interiors'},
    {'capture','Capture##turfs','Automatically capture turfs - /acapt','Run capture command periodically - /spamt','Capture spam interval'},
    {'capture','Points','Show upcoming point war info','Show active point war info'},
    {'capture','Capture##points','Automatically capture points - /acapp'},
    {'capture','Position##capture','Turf and point overlay position'},
    {'phone','Phone','Show Player ID','Colorize Name','Hide Extra Lines'},
    {'phone','SMS Players','Send SMS - /pm'}
}
function S.find(query,pages)
    local terms={}
    for term in query:lower():gmatch('%S+') do terms[#terms+1]=term end
    if #terms==0 then return {} end
    local results={}
    for _,section in ipairs(sections) do
        local id,anchor=section[1],section[2]
        local page=pages[id]
        if page then
            local group=anchor and anchor:gsub('##.*$','') or page.title
            local function matches(text)
                text=text:lower()
                for _,term in ipairs(terms) do
                    if not text:find(term,1,true) then return false end
                end
                return true
            end
            if anchor=='Capture##turfs' then group='Turf Capture' end
            if anchor=='Capture##points' then group='Point Capture' end
            local group_result={page=id,anchor=anchor,heading=group==page.title and page.title or page.title..'  /  '..group,items={}}
            local group_matches=matches(group)
            for i=3,#section do
                local label=section[i]
                if matches(label) or (not group_matches and matches(group..' '..label)) then
                    group_result.items[#group_result.items+1]=label
                end
            end
            if #group_result.items==0 and group_matches then group_result.items[1]=group end
            if #group_result.items>0 then results[#results+1]=group_result end
        end
    end
    return results
end
return S

end

package.preload['src.ui.SkinPicker'] = function()
local imgui=require('upmimgui')
local H=require('src.ui.Helpers')
local catalog=require('src.core.SkinCatalog')
local S={open=false,query='',textures={},selected={},ids={}}
function S:show(ids,on_done)
    self.open=true;self.query='';self.on_done=on_done;self.ids={};self.selected={}
    for _,id in ipairs(ids)do if not self.selected[id]then self.ids[#self.ids+1]=id;self.selected[id]=true end end
end
function S:toggle(id)
    if self.selected[id]then
        self.selected[id]=nil
        for i,n in ipairs(self.ids)do if n==id then table.remove(self.ids,i);break end end
    else self.selected[id]=true;self.ids[#self.ids+1]=id end
end
function S:render()
    if not self.open then return end
    if not imgui.IsPopupOpen('Skin images')then imgui.OpenPopup('Skin images')end
    local display=imgui.GetIO().DisplaySize
    local width=math.min(1240,display.x-40)
    local height=math.min(1000,display.y-40)
    local columns=math.max(1,math.min(6,math.floor((width-36)/195)))
    imgui.SetNextWindowSize(imgui.ImVec2(width,height),imgui.Cond.Always)
    local flags=imgui.WindowFlags.NoResize+imgui.WindowFlags.NoScrollbar+imgui.WindowFlags.NoScrollWithMouse
    if imgui.BeginPopupModal('Skin images',nil,flags)then
        self.query=H.input('##skin_search',self.query,'Search skin ID',imgui.GetContentRegionAvail().x,3)
        local available=imgui.GetContentRegionAvail()
        imgui.BeginChild('skin_grid',imgui.ImVec2(0,math.max(80,available.y-124)),false)
        if imgui.BeginTable('skins',columns)then
            for _,s in ipairs(catalog)do
                if self.query=='' or tostring(s.id):find(self.query,1,true)then
                    imgui.TableNextColumn();imgui.PushID(s.id)
                    local visible=imgui.IsRectVisible(imgui.ImVec2(s.width,s.height))
                    if self.textures[s.id]==nil and visible then
                        local folder=(s.id==1 or s.id==2)and 'skin-overrides/' or 'skins/'
                        local ok,tex=pcall(imgui.CreateTextureFromFile,getWorkingDirectory()..'/resource/Leone Menu/'..folder..s.id..'.png')
                        self.textures[s.id]=ok and tex or false
                    end
                    local origin=imgui.GetCursorScreenPos()
                    local size=imgui.ImVec2(s.width,s.height)
                    local finish=imgui.ImVec2(origin.x+size.x,origin.y+size.y)
                    imgui.InvisibleButton('##skin',size)
                    local hovered=imgui.IsItemHovered()
                    if imgui.IsItemClicked(0)then self:toggle(s.id)end
                    local draw=imgui.GetWindowDrawList()
                    if hovered or self.selected[s.id]then
                        draw:AddRectFilled(origin,finish,imgui.GetColorU32(imgui.ImVec4(.17,.25,.33,hovered and .32 or .22)),8)
                    end
                    if self.textures[s.id]then draw:AddImage(self.textures[s.id],origin,finish)end
                    if self.selected[s.id]then draw:AddRect(origin,finish,imgui.GetColorU32(H.color),8,0,2)end
                    local label='ID '..s.id
                    local text=imgui.CalcTextSize(label)
                    local at=imgui.ImVec2(origin.x+(size.x-text.x)/2,origin.y+(size.y-text.y)/2)
                    draw:AddRectFilled(imgui.ImVec2(at.x-7,at.y-4),imgui.ImVec2(at.x+text.x+7,at.y+text.y+4),imgui.GetColorU32(imgui.ImVec4(0,0,0,.65)),5)
                    draw:AddText(at,0xFFFFFFFF,label)
                    imgui.PopID()
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
        imgui.Separator()
        imgui.BeginChild('selected_skin_ids',imgui.ImVec2(0,54),false)
        imgui.TextWrapped('Selected IDs: '..(#self.ids>0 and table.concat(self.ids,', ')or 'None'))
        imgui.EndChild()
        local done_width=200
        imgui.SetCursorPosX((imgui.GetWindowWidth()-done_width)/2)
        if imgui.AnimButton('Done',imgui.ImVec2(done_width,40))then
            self.on_done(self.ids);self.open=false;imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
end
return S

end

package.preload['src.ui.Widgets'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\ui\Widgets.lua

local fa = require("fAwesome7")
local ffi = require("ffi")
local imgui = require("upmimgui")

local function ImGuiEnum(name)
    return setmetatable({ __name = name }, {
        __index = function(t, k)
            return imgui.lib[t.__name .. k]
        end
    })
end

imgui.DrawFlags = ImGuiEnum("ImDrawFlags_")
imgui.ChildFlags = ImGuiEnum("ImGuiChildFlags_")
imgui.TableFlags = ImGuiEnum("ImGuiTableFlags_")
imgui.TableColumnFlags = ImGuiEnum("ImGuiTableColumnFlags_")

local function show_cursor_on_hover(orig_func)
    return function(...)
        local result = orig_func(...)
        if imgui.IsItemHovered() then
            imgui.SetMouseCursor(imgui.MouseCursor.Hand)
        end
        return result
    end
end

imgui.Button = show_cursor_on_hover(imgui.Button)
imgui.SmallButton = show_cursor_on_hover(imgui.SmallButton)
imgui.InvisibleButton = show_cursor_on_hover(imgui.InvisibleButton)
imgui.Checkbox = show_cursor_on_hover(imgui.Checkbox)
imgui.Selectable = show_cursor_on_hover(imgui.Selectable)
imgui.ColorButton = show_cursor_on_hover(imgui.ColorButton)
imgui.ColorEdit4 = show_cursor_on_hover(imgui.ColorEdit4)
imgui.DragFloat = show_cursor_on_hover(imgui.DragFloat)
imgui.DragInt = show_cursor_on_hover(imgui.DragInt)
imgui.SliderInt = show_cursor_on_hover(imgui.SliderInt)
imgui.BeginCombo = show_cursor_on_hover(imgui.BeginCombo)

function imgui.ScaleValue(value)
    local font_factor = imgui.GetFontSize()
    return value * font_factor
end

function imgui.ScaleVec2(vec)
    return imgui.ImVec2(imgui.ScaleValue(vec.x), imgui.ScaleValue(vec.y))
end

function imgui.ToggleButtonWidth()
    local height = imgui.GetFrameHeight()
    local width = height * 2.7
    return width
end

function imgui.SemiCircularSlider(id, value, min, max, radius, format, tooltip, text, disabled)
    local style = imgui.GetStyle()
    local io = imgui.GetIO()

    radius = radius or (imgui.GetFontSize() * 3.2)
    format = format or ""
    disabled = disabled or false

    local angle_min, angle_max = math.pi * 0.75, math.pi * 2.25
    local arc_thickness = imgui.GetFontSize() * 0.3
    local knob_radius = imgui.GetFontSize() * 0.45

    local function normalize(val)
        return imgui.ImSaturate((val - min) / (max - min))
    end

    local storage = imgui.GetStateStorage()
    local angle_key = imgui.GetID(id .. "_angle")
    local normalized_key = imgui.GetID(id .. "_normalized")

    local normalized_value = normalize(value[0])
    local target_angle = angle_min + (angle_max - angle_min) * normalized_value
    local current_angle = storage:GetFloat(angle_key, target_angle)
    local current_normalized = storage:GetFloat(normalized_key, normalized_value)

    local label_height = text and imgui.CalcTextSize(text).y or 0
    local total_size = imgui.ImVec2(radius * 2, radius * 2 + label_height + 5)
    imgui.InvisibleButton("##" .. id, total_size)

    local is_active = imgui.IsItemActive() and not disabled
    local is_hovered = imgui.IsItemHovered() and not disabled

    local cursor_pos = imgui.GetItemRectMin()
    local center = imgui.ImVec2(cursor_pos.x + radius, cursor_pos.y + radius)
    local draw_list = imgui.GetWindowDrawList()

    local delta_time = io.DeltaTime
    local speed = is_active and 20.0 or 8.0
    local angle_diff = target_angle - current_angle

    local factor = imgui.ImSaturate(delta_time * speed)
    current_angle = current_angle + angle_diff * factor
    current_normalized = current_normalized + (normalized_value - current_normalized) * factor

    local segments = math.max(48, math.ceil(radius * 1.2))

    draw_list:PathArcTo(center, radius, angle_min, angle_max, segments)
    draw_list:PathStroke(imgui.GetColorU32(imgui.ImVec4(0.24, 0.24, 0.27, 1)), false, arc_thickness)

    if current_normalized > 0.01 then
        local filled_angle = current_angle
        local col = disabled and imgui.ImLerp(style.Colors[imgui.Col.SliderGrab], imgui.ImVec4(0, 0, 0, 1), 0.5)
            or style.Colors[imgui.Col.SliderGrab]
        draw_list:PathArcTo(center, radius, angle_min, filled_angle, segments)
        draw_list:PathStroke(imgui.GetColorU32(col), false, arc_thickness)
    end

    local knob_color = disabled and style.Colors[imgui.Col.TextDisabled]
        or (is_active and style.Colors[imgui.Col.SliderGrabActive] or style.Colors[imgui.Col.SliderGrab])
    local knob_pos = imgui.ImVec2(center.x + radius * math.cos(current_angle),
        center.y + radius * math.sin(current_angle))
    draw_list:AddCircleFilled(knob_pos, knob_radius, imgui.GetColorU32(knob_color), 12)

    local value_text = string.format("%d%s", value[0], format)
    local text_size = imgui.CalcTextSize(value_text)
    draw_list:AddText(imgui.ImVec2(center.x - text_size.x * 0.5, center.y - text_size.y * 0.5),
        imgui.GetColorU32(disabled and style.Colors[imgui.Col.TextDisabled] or style.Colors[imgui.Col.Text]),
        value_text)

    if text then
        local label_size = imgui.CalcTextSize(text)
        draw_list:AddText(imgui.ImVec2(cursor_pos.x + radius - label_size.x * 0.5,
                cursor_pos.y + radius * 2 + 5),
            imgui.GetColorU32(disabled and style.Colors[imgui.Col.TextDisabled] or style.Colors[imgui.Col.Text]),
            text)
    end

    if tooltip and is_hovered then
        imgui.BeginTooltip()
        imgui.Text(tooltip)
        imgui.EndTooltip()
    end

    if is_active and imgui.IsMouseDown(0) then
        local mouse = imgui.GetMousePos()
        local mouse_angle = math.atan2(mouse.y - center.y, mouse.x - center.x)

        if mouse_angle < 0 then
            mouse_angle = mouse_angle + 2 * math.pi
        end

        if mouse_angle < angle_min - math.pi * 0.25 then
            mouse_angle = mouse_angle + 2 * math.pi
        end

        if mouse_angle >= angle_min and mouse_angle <= angle_max then
            local new_norm = (mouse_angle - angle_min) / (angle_max - angle_min)
            value[0] = math.max(min, math.min(max, math.floor(min + (max - min) * new_norm + 0.5)))
            current_angle = mouse_angle
            current_normalized = new_norm
        end
    end

    storage:SetFloat(angle_key, current_angle)
    storage:SetFloat(normalized_key, current_normalized)

    return is_active
end

function imgui.Hint(str_id, hint)
    local animation_duration = 0.4
    local current_time = imgui.GetTime()
    local is_hovered = imgui.IsItemHovered()

    local storage = imgui.GetStateStorage()
    local start_time_key = imgui.GetID(str_id .. "_hint_start")
    local was_hovered_key = imgui.GetID(str_id .. "_was_hovered")

    local was_hovered = storage:GetBool(was_hovered_key, false)

    if is_hovered then
        local start_time = storage:GetFloat(start_time_key, -1)

        if not was_hovered or start_time == -1 then
            start_time = current_time
            storage:SetFloat(start_time_key, start_time)
        end

        local elapsed = current_time - start_time
        local alpha = math.min(elapsed / animation_duration, 1.0)

        if alpha > 0.01 then
            imgui.PushStyleVar_Float(imgui.StyleVar.Alpha, alpha)
            imgui.SetTooltip(hint)
            imgui.PopStyleVar()
        end
    end

    storage:SetBool(was_hovered_key, is_hovered)
end

function imgui.StatusDot(id, radius, selected)
    local cursor_pos = imgui.GetCursorScreenPos()
    local center = imgui.ImVec2(cursor_pos.x + radius, cursor_pos.y + radius)
    local style = imgui.GetStyle()

    local storage = imgui.GetStateStorage()
    local progress_key = imgui.GetID(id .. "_status_progress")

    local animation_progress = storage:GetFloat(progress_key, selected and 1.0 or 0.0)

    local target = selected and 1.0 or 0.0
    local animation_speed = 12.0
    local delta_time = imgui.GetIO().DeltaTime
    animation_progress = animation_progress +
        (target - animation_progress) * imgui.ImSaturate(delta_time * animation_speed)

    storage:SetFloat(progress_key, animation_progress)

    local icon = animation_progress > 0.5 and fa("CIRCLE_CHECK") or fa("CIRCLE_XMARK")
    local check_color = style.Colors[imgui.Col.CheckMark]
    local disabled_color = style.Colors[imgui.Col.TextDisabled]
    local status_color = imgui.ImLerp(disabled_color, check_color, animation_progress)

    local icon_size = imgui.CalcTextSize(icon)
    imgui.SetCursorScreenPos(imgui.ImVec2(center.x - icon_size.x / 2, center.y - icon_size.y / 2))
    imgui.TextColored(status_color, icon)

    imgui.SetCursorScreenPos(cursor_pos)
    if imgui.InvisibleButton(id, imgui.ImVec2(radius * 2, radius * 2)) then
        selected = not selected
    end

    imgui.SetCursorScreenPos(imgui.ImVec2(cursor_pos.x + radius * 2, cursor_pos.y))
    return selected
end

function imgui.PageButton(active, icon, label, button_width, status_opts, icon_box_color)
    local style = imgui.GetStyle()
    local button_height = imgui.GetFrameHeight() * 1.2
    local rounding = style.FrameRounding

    local draw_list = imgui.GetWindowDrawList()
    local cursor_pos = imgui.GetCursorScreenPos()

    local str_id = label:match('##.+$') or label
    label = label:gsub('##.+$', '')

    local storage = imgui.GetStateStorage()
    local click_time_key = imgui.GetID(str_id .. "_click_time")
    local hover_start_key = imgui.GetID(str_id .. "_hover_start")

    local click_time = storage:GetFloat(click_time_key, 0.0)
    local hover_start = storage:GetFloat(hover_start_key, 0.0)

    local adjusted_button_width = button_width
    if status_opts then
        adjusted_button_width = button_width - 30
    end

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0, 0, 0, 0))
    local clicked = imgui.InvisibleButton(str_id, imgui.ImVec2(adjusted_button_width, button_height))
    imgui.PopStyleColor(3)

    local is_hovered = imgui.IsItemHovered()
    if clicked and not active then
        click_time = os.clock()
        storage:SetFloat(click_time_key, click_time)
    end

    local anim_speed = 0.32
    local hover_progress = 0

    if is_hovered and hover_start <= 0 then
        hover_start = os.clock()
        storage:SetFloat(hover_start_key, hover_start)
    elseif not is_hovered and hover_start > 0 then
        hover_start = -os.clock()
        storage:SetFloat(hover_start_key, hover_start)
    end

    if hover_start > 0 then
        hover_progress = imgui.ImSaturate((os.clock() - hover_start) / anim_speed)
    elseif hover_start < 0 then
        hover_progress = imgui.ImSaturate(1 - (os.clock() + hover_start) / anim_speed)
        if hover_progress == 0 then
            hover_start = 0
            storage:SetFloat(hover_start_key, hover_start)
        end
    end

    local elapsed = os.clock() - click_time
    local active_alpha = imgui.ImSaturate(elapsed / 0.3) * 0.6

    local active_bg = imgui.ImVec4(
        style.Colors[imgui.Col.ButtonActive].x,
        style.Colors[imgui.Col.ButtonActive].y,
        style.Colors[imgui.Col.ButtonActive].z,
        imgui.ImSaturate(active_alpha)
    )
    local hover_bg = style.Colors[imgui.Col.ButtonHovered]
    local base_bg = active and active_bg or imgui.ImVec4(0, 0, 0, 0)
    local bg_color = active and base_bg or imgui.ImLerp(base_bg, hover_bg, hover_progress)

    if bg_color.w > 0 then
        draw_list:AddRectFilled(
            cursor_pos,
            imgui.ImVec2(cursor_pos.x + button_width, cursor_pos.y + button_height),
            imgui.ColorConvertFloat4ToU32(bg_color),
            rounding
        )
    end

    local icon_box_size = imgui.GetFontSize() * 1.5
    local icon_box_padding = style.FramePadding.x
    local icon_box_x = cursor_pos.x + icon_box_padding
    local icon_box_y = cursor_pos.y + (button_height - icon_box_size) * 0.5
    icon_box_color = icon_box_color or style.Colors[imgui.Col.ButtonActive]
    draw_list:AddRectFilled(
        imgui.ImVec2(icon_box_x, icon_box_y),
        imgui.ImVec2(icon_box_x + icon_box_size, icon_box_y + icon_box_size),
        imgui.ColorConvertFloat4ToU32(icon_box_color),
        style.FrameRounding * 0.75
    )

    local icon_size = imgui.CalcTextSize(icon)
    local icon_x = icon_box_x + (icon_box_size - icon_size.x) * 0.5
    local icon_y = icon_box_y + (icon_box_size - icon_size.y) * 0.5

    imgui.SetCursorScreenPos(imgui.ImVec2(icon_x, icon_y))
    imgui.TextColored(
        active and style.Colors[imgui.Col.Text] or style.Colors[imgui.Col.TextDisabled],
        icon
    )

    local text_size = imgui.CalcTextSize(label)
    local label_x = icon_box_x + icon_box_size + style.ItemSpacing.x
    local label_y = cursor_pos.y + (button_height - text_size.y) * 0.5

    imgui.SetCursorScreenPos(imgui.ImVec2(label_x, label_y))
    imgui.TextColored(
        active and style.Colors[imgui.Col.Text] or style.Colors[imgui.Col.TextDisabled],
        label
    )

    if status_opts then
        local dot_radius = imgui.GetFontSize() * 0.5
        local dot_x = cursor_pos.x + button_width - style.FramePadding.x - (dot_radius * 2)
        local dot_y = cursor_pos.y + (button_height / 2) - dot_radius

        local prev_cursor = imgui.GetCursorScreenPos()
        imgui.SetCursorScreenPos(imgui.ImVec2(dot_x, dot_y))

        local status_id = str_id .. "_status"
        local old_value = status_opts.value
        status_opts.value = imgui.StatusDot(status_id, dot_radius, status_opts.value)

        imgui.SetCursorScreenPos(prev_cursor)

        if status_opts.on_toggle and old_value ~= status_opts.value then
            status_opts.on_toggle(status_opts.value)
        end
    end

    imgui.Dummy(imgui.ImVec2(0, style.ItemSpacing.y * 0.5))

    return clicked
end

function imgui.Heading(text)
    local heading_size = imgui.GetFontSize() * 1.2
    imgui.PushFont(nil, heading_size)
    imgui.Text(text)
    imgui.PopFont()
end

function imgui.StyledInputText(id, value, hint, size, max_len, flags)

    flags = flags or 0
    value = value or ""
    max_len = max_len or 256

    local style = imgui.GetStyle()

    if #value > max_len then
        value = value:sub(1, max_len)
    end

    local buf_size = max_len + 1
    local buf = ffi.new("char[?]", buf_size, value)

    local min_width = imgui.GetFontSize() * 7.5
    local width = min_width
    if size then
        if size.x == -1 then
            width = imgui.GetContentRegionAvail().x
        else
            width = size.x
        end
    elseif hint then
        width = math.max(imgui.CalcTextSize(hint).x + style.FramePadding.x * 4, min_width)
    end

    imgui.PushItemWidth(width)
    local changed = imgui.InputTextWithHint("##" .. id, hint or "", buf, buf_size, flags)
    imgui.PopItemWidth()

    local out = ffi.string(buf)

    return out, changed
end

function imgui.DrawChild(name, content_callback, size)
    if imgui.BeforeSettingsSection then imgui.BeforeSettingsSection(name) end
    size = size or imgui.ImVec2(-1, 0)
    local style = imgui.GetStyle()

    local storage = imgui.GetStateStorage()
    local fade_key = imgui.GetID(name .. "_fade_alpha")
    local last_frame_key = imgui.GetID(name .. "_last_frame")

    local current_frame = imgui.GetFrameCount()
    local last_frame = storage:GetInt(last_frame_key, -1)
    local is_first_frame = (last_frame == -1) or (current_frame > last_frame + 1)

    storage:SetInt(last_frame_key, current_frame)

    local current_alpha = storage:GetFloat(fade_key, is_first_frame and 0.0 or 1.0)
    if is_first_frame then current_alpha = 0.0 end

    local target_alpha = 1.0
    local fade_speed = 4.0
    local delta_time = imgui.GetIO().DeltaTime

    current_alpha = current_alpha + (target_alpha - current_alpha) * imgui.ImSaturate(delta_time * fade_speed)
    storage:SetFloat(fade_key, current_alpha)

    imgui.PushStyleVar(imgui.StyleVar.Alpha, current_alpha)
    imgui.BeginChild(name, size, imgui.ChildFlags.AlwaysUseWindowPadding + imgui.ChildFlags.AutoResizeY, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)

    local has_visible_heading = not name:match("^##(.+)$")
    if has_visible_heading then
        local display_name = name:match("^(.-)##") or name
        local available_width = imgui.GetContentRegionAvail().x

        local heading_font_size = imgui.GetFontSize() * 1.2
        imgui.PushFont(nil, heading_font_size)
        local text_size = imgui.CalcTextSize(display_name)
        imgui.PopFont()

        local padding = style.WindowPadding.y
        local rect_height = text_size.y + padding * 2

        local cursor_screen_pos = imgui.GetCursorScreenPos()
        local draw_list = imgui.GetWindowDrawList()
        draw_list:AddRectFilled(
            cursor_screen_pos,
            imgui.ImVec2(cursor_screen_pos.x + available_width, cursor_screen_pos.y + rect_height),
            imgui.GetColorU32(style.Colors[imgui.Col.ChildBg]),
            style.ChildRounding
        )

        local child_cursor_pos = imgui.GetCursorPos()
        imgui.SetCursorPos(imgui.ImVec2(
            child_cursor_pos.x + (available_width - text_size.x) * 0.5,
            child_cursor_pos.y + padding
        ))
        imgui.Heading(display_name)

        imgui.SetCursorPos(imgui.ImVec2(child_cursor_pos.x, child_cursor_pos.y + rect_height + padding))
    end

    content_callback(imgui.GetContentRegionAvail().x + style.WindowPadding.x)

    imgui.EndChild()
    imgui.PopStyleVar()
end

function imgui.DrawChildrenRow(children, spacing)
    local available_width = imgui.GetContentRegionAvail().x
    local style_spacing = imgui.GetStyle().ItemSpacing.x
    local total_spacing = (spacing or style_spacing) * (#children - 1)
    local remaining_width = available_width - total_spacing

    for i, child in ipairs(children) do
        local width = child.width or (remaining_width / #children)

        if i > 1 then
            imgui.SameLine()
            if spacing and spacing > 0 then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + spacing - style_spacing)
            end
        end

        imgui.DrawChild(
            child.name,
            child.content_callback,
            imgui.ImVec2(width, 0)
        )
    end
end

function imgui.ToggleButton(str_id, state, text, disabled)
    local pos=imgui.GetCursorScreenPos()
    local h=imgui.GetFrameHeight();local w=h*2.7
    local draw=imgui.GetWindowDrawList()
    imgui.InvisibleButton(str_id,imgui.ImVec2(w,h))
    local clicked=imgui.IsItemClicked(0) and not disabled
    if clicked then state[0]=not state[0] end
    local on=state[0]
    local bg=on and imgui.ImVec4(30/255,51/255,72/255,1) or imgui.ImVec4(0.12,0.12,0.14,1)
    local border=on and imgui.ImVec4(0.5,0.64,0.77,1) or imgui.ImVec4(0.45,0.45,0.48,1)
    local ink=disabled and imgui.ImVec4(0.48,0.48,0.5,1) or imgui.ImVec4(1,1,1,1)
    draw:AddRectFilled(pos,imgui.ImVec2(pos.x+w,pos.y+h),imgui.GetColorU32(bg),h/2)
    draw:AddRect(pos,imgui.ImVec2(pos.x+w,pos.y+h),imgui.GetColorU32(border),h/2)
    local r=h*0.31
    local cx=on and (pos.x+w-h/2) or (pos.x+h/2)
    draw:AddCircleFilled(imgui.ImVec2(cx,pos.y+h/2),r,imgui.GetColorU32(ink),16)
    local label=on and 'ON' or 'OFF';local size=imgui.CalcTextSize(label)
    local tx=on and pos.x+h*0.34 or pos.x+h*1.1
    draw:AddText(imgui.ImVec2(tx,pos.y+(h-size.y)/2),imgui.GetColorU32(ink),label)
    if text then imgui.SameLine();imgui.Text(text) end
    return clicked
end

function imgui.SegmentedControl(name, items, selected_item_ptr, fixed_size)
    local style = imgui.GetStyle()
    local draw_list = imgui.GetWindowDrawList()
    local colors = style.Colors
    local start_pos = imgui.GetCursorScreenPos()
    local item_height = fixed_size and fixed_size.y > 0 and fixed_size.y or (imgui.GetFrameHeight())

    local storage = imgui.GetStateStorage()
    local selected_pos_key = imgui.GetID(name .. "_selected_pos")
    local target_pos_key = imgui.GetID(name .. "_target_pos")

    local selected_pos = storage:GetFloat(selected_pos_key, 0.0)
    local target_pos = storage:GetFloat(target_pos_key, 0.0)

    local total_width = 0
    local item_widths = {}

    if fixed_size then

        local available_width = fixed_size.x == -1 and imgui.GetContentRegionAvail().x or fixed_size.x
        local item_width = available_width / #items

        for i = 1, #items do
            item_widths[i] = item_width
        end

        total_width = available_width
    else

        for i, item in ipairs(items) do
            local item_width = imgui.CalcTextSize(item).x + style.FramePadding.x * 2
            item_widths[i] = item_width
            total_width = total_width + item_width
        end
    end

    target_pos = 0
    for i = 1, selected_item_ptr[0] do
        target_pos = target_pos + (item_widths[i] or 0)
    end
    storage:SetFloat(target_pos_key, target_pos)

    local animation_speed = 12.0
    local delta_time = imgui.GetIO().DeltaTime
    selected_pos = selected_pos + (target_pos - selected_pos) * imgui.ImSaturate(delta_time * animation_speed)
    storage:SetFloat(selected_pos_key, selected_pos)

    local border_color = imgui.GetColorU32(colors[imgui.Col.Border])
    draw_list:AddRect(
        start_pos,
        imgui.ImVec2(start_pos.x + total_width, start_pos.y + item_height),
        border_color,
        style.FrameRounding,
        nil,
        math.max(style.FrameBorderSize, 1)
    )

    if selected_item_ptr[0] >= 0 and selected_item_ptr[0] < #items then
        local selected_width = item_widths[selected_item_ptr[0] + 1] or 0
        local selected_bg_min = imgui.ImVec2(start_pos.x + selected_pos, start_pos.y)
        local selected_bg_max = imgui.ImVec2(selected_bg_min.x + selected_width, start_pos.y + item_height)

        local rounding, flags = 0, nil
        if #items == 1 then
            rounding = style.FrameRounding
        elseif selected_item_ptr[0] == 0 then
            rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersLeft
        elseif selected_item_ptr[0] == #items - 1 then
            rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersRight
        end

        draw_list:AddRectFilled(
            selected_bg_min,
            selected_bg_max,
            imgui.GetColorU32(colors[imgui.Col.Button]),
            rounding,
            flags
        )
    end

    local current_pos = start_pos
    for index, item in ipairs(items) do
        local item_width = item_widths[index]

        local hover_alpha_key = imgui.GetID(name .. "_hover_alpha_" .. index)
        local hover_target_key = imgui.GetID(name .. "_hover_target_" .. index)

        local hover_alpha = storage:GetFloat(hover_alpha_key, 0.0)
        local hover_target = storage:GetFloat(hover_target_key, 0.0)

        imgui.SetCursorScreenPos(current_pos)
        if imgui.InvisibleButton('##selector_' .. name .. '_' .. index, imgui.ImVec2(item_width, item_height)) then
            selected_item_ptr[0] = index - 1
        end

        local is_selected = selected_item_ptr[0] == index - 1
        local is_hovered = imgui.IsItemHovered()

        hover_target = (is_hovered and not is_selected) and 1.0 or 0.0
        hover_alpha = hover_alpha + (hover_target - hover_alpha) * 8.0 * delta_time

        storage:SetFloat(hover_alpha_key, hover_alpha)
        storage:SetFloat(hover_target_key, hover_target)

        if not is_selected and hover_alpha > 0.01 then
            local base_color = colors[imgui.Col.FrameBg]
            local hover_color = colors[imgui.Col.ButtonHovered]
            local hover_bg_color = imgui.ImVec4(
                base_color.x + (hover_color.x - base_color.x) * hover_alpha,
                base_color.y + (hover_color.y - base_color.y) * hover_alpha,
                base_color.z + (hover_color.z - base_color.z) * hover_alpha,
                base_color.w + (hover_color.w - base_color.w) * hover_alpha
            )

            local rounding, flags = 0, nil
            if index == 1 and index == #items then
                rounding = style.FrameRounding
            elseif index == 1 then
                rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersLeft
            elseif index == #items then
                rounding, flags = style.FrameRounding, imgui.DrawFlags.RoundCornersRight
            end

            local item_rect_max = imgui.ImVec2(current_pos.x + item_width, current_pos.y + item_height)
            draw_list:AddRectFilled(current_pos, item_rect_max, imgui.GetColorU32(hover_bg_color), rounding, flags)
        end

        if index > 1 then
            local y_offset = style.CellPadding.y
            local separator_color = imgui.GetColorU32(colors[imgui.Col.Border])
            local border_width = math.max(style.FrameBorderSize, 1)
            draw_list:AddLine(
                imgui.ImVec2(current_pos.x, current_pos.y + y_offset),
                imgui.ImVec2(current_pos.x, current_pos.y + item_height - y_offset),
                separator_color,
                border_width
            )
        end

        local text_size = imgui.CalcTextSize(item)
        local text_pos = imgui.ImVec2(
            current_pos.x + (item_width - text_size.x) * 0.5,
            current_pos.y + (item_height - text_size.y) * 0.5
        )

        local text_color = is_selected and colors[imgui.Col.Text] or
            (hover_alpha > 0.01 and
                imgui.ImLerp(colors[imgui.Col.TextDisabled], colors[imgui.Col.Text], hover_alpha) or
                colors[imgui.Col.TextDisabled])

        draw_list:AddText(text_pos, imgui.GetColorU32(text_color), item)
        current_pos.x = current_pos.x + item_width
    end
end

function imgui.DataTable(id, options)

    if not imgui._datatable_strings then
        imgui._datatable_strings = {}
    end
    local string_storage = imgui._datatable_strings

    local storage = imgui.GetStateStorage()
    local sort_column_key = imgui.GetID(id .. "_sort_column")
    local sort_ascending_key = imgui.GetID(id .. "_sort_ascending")
    local current_page_key = imgui.GetID(id .. "_current_page")

    local sort_column = storage:GetInt(sort_column_key, -1)
    local sort_ascending = storage:GetInt(sort_ascending_key, 1) == 1
    local current_page = storage:GetInt(current_page_key, 1)

    local column_filters = {}
    local has_column_filters = false

    for _, column in ipairs(options.columns) do
        if column.filterable then
            has_column_filters = true
            local filter_key = id .. "_filter_" .. column.key
            column_filters[column.key] = string_storage[filter_key] or ""
        end
    end

    local data_changed = false

    if has_column_filters then
        if imgui.AnimButton(fa("FILTER") .. " Filters") then
            imgui.OpenPopup("FILTER:" .. id)
        end

        if imgui.BeginPopup("FILTER:" .. id) then
            imgui.Text("Column Filters")
            imgui.Separator()

            for _, column in ipairs(options.columns) do
                if column.filterable then
                    local filter_text, filter_changed = imgui.StyledInputText(
                        "##filter_" .. column.key,
                        column_filters[column.key],
                        "Filter by " .. column.label:lower(),
                        imgui.ImVec2(300, 0)
                    )
                    if filter_changed then
                        column_filters[column.key] = filter_text
                        local filter_key = id .. "_filter_" .. column.key
                        string_storage[filter_key] = filter_text
                        current_page = 1
                        storage:SetInt(current_page_key, current_page)
                    end
                end
            end

            imgui.Separator()
            if imgui.AnimButton("Clear All Filters", imgui.ImVec2(-1, 0)) then
                for _, column in ipairs(options.columns) do
                    if column.filterable then
                        column_filters[column.key] = ""
                        local filter_key = id .. "_filter_" .. column.key
                        string_storage[filter_key] = ""
                    end
                end
                current_page = 1
                storage:SetInt(current_page_key, current_page)
            end

            imgui.EndPopup()
        end

        imgui.Separator()
    end

    local display_data = {}
    for i, row in ipairs(options.data) do
        local include_row = true

        for _, column in ipairs(options.columns) do
            if column.filterable and column_filters[column.key] ~= "" then
                local value = row[column.key] or ""
                local display_value = column.format and column.format(value, row) or tostring(value)
                local filter_text = string.lower(column_filters[column.key])
                local search_text = string.lower(display_value)

                if not string.find(search_text, filter_text, 1, true) then
                    include_row = false
                    break
                end
            end
        end

        if include_row then
            table.insert(display_data, { data = row, original_index = i })
        end
    end

    if sort_column >= 0 and sort_column < #options.columns then
        local sort_key = options.columns[sort_column + 1].key
        table.sort(display_data, function(a, b)
            local val_a, val_b = a.data[sort_key], b.data[sort_key]

            if val_a == nil and val_b == nil then
                return false
            elseif val_a == nil then
                return not sort_ascending
            elseif val_b == nil then
                return sort_ascending
            end

            local num_a, num_b = tonumber(val_a), tonumber(val_b)
            if num_a and num_b then
                if sort_ascending then
                    return num_a < num_b
                else
                    return num_a > num_b
                end
            end

            local str_a, str_b = tostring(val_a):lower(), tostring(val_b):lower()
            if sort_ascending then
                return str_a < str_b
            else
                return str_a > str_b
            end
        end)
    end

    local page_size = options.page_size or 10
    local total_pages = math.ceil(#display_data / page_size)

    local table_flags = imgui.TableFlags.RowBg + imgui.TableFlags.Resizable + imgui.TableFlags.ScrollY
    if options.sortable ~= false then
        table_flags = table_flags + imgui.TableFlags.Sortable
    end

    local column_count = #options.columns
    if options.buttons and #options.buttons > 0 then
        column_count = column_count + 1
    end

    local table_height = imgui.GetFrameHeight() * (page_size + 2)

    if imgui.BeginTable(id .. "_table", column_count, table_flags, imgui.ImVec2(0, table_height)) then
        for _, column in ipairs(options.columns) do
            local column_flags = imgui.TableColumnFlags.WidthStretch
            if not column.sortable then
                column_flags = column_flags + imgui.TableColumnFlags.NoSort
            end

            local column_weight = column.width or 1.0
            imgui.TableSetupColumn(column.label, column_flags, column_weight)
        end

        if options.buttons and #options.buttons > 0 then
            local action_width = math.max(#options.buttons * 35 + 20, 100)
            imgui.TableSetupColumn("Actions", imgui.TableColumnFlags.WidthFixed + imgui.TableColumnFlags.NoSort,
                action_width)
        end

        imgui.TableHeadersRow()

        local sort_specs = imgui.TableGetSortSpecs()
        if sort_specs and sort_specs.SpecsDirty then
            if sort_specs.SpecsCount > 0 then
                local spec = sort_specs.Specs[0]
                local col = spec.ColumnIndex
                local sort_dir = spec.SortDirection or 1

                sort_column = col
                sort_ascending = sort_dir == 1
                storage:SetInt(sort_column_key, sort_column)
                storage:SetInt(sort_ascending_key, sort_ascending and 1 or 0)
            else
                sort_column = -1
                storage:SetInt(sort_column_key, sort_column)
            end
            sort_specs.SpecsDirty = false
        end

        if current_page > total_pages then
            current_page = math.max(1, total_pages)
            storage:SetInt(current_page_key, current_page)
        end

        local start_idx = (current_page - 1) * page_size + 1
        local end_idx = math.min(start_idx + page_size - 1, #display_data)

        if #display_data > 0 and start_idx <= #display_data then
            for idx = start_idx, end_idx do
                local row_entry = display_data[idx]
                if not row_entry then break end

                local original_idx = row_entry.original_index
                local row_data = row_entry.data

                imgui.TableNextRow()

                for i, column in ipairs(options.columns) do
                    imgui.TableNextColumn()
                    local value = row_data[column.key] or ""
                    local display_value = column.format and column.format(value, row_data) or tostring(value)
                    imgui.Text(display_value)
                end

                if options.buttons and #options.buttons > 0 then
                    imgui.TableNextColumn()

                    for j, button in ipairs(options.buttons) do
                        local visible = not button.visible or button.visible(row_data, original_idx)

                        if visible then
                            if j > 1 then imgui.SameLine() end

                            if button.color then
                                imgui.PushStyleColor(imgui.Col.Button, button.color)
                                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                                    button.color.x * 1.1, button.color.y * 1.1, button.color.z * 1.1, button.color.w
                                ))
                                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(
                                    button.color.x * 0.9, button.color.y * 0.9, button.color.z * 0.9, button.color.w
                                ))
                            end

                            local button_text = button.label
                            if button.icon then
                                button_text = button.icon
                                if button.label and button.label ~= "" then
                                    button_text = button_text .. " " .. button.label
                                end
                            end

                            local default_button_size = imgui.ImVec2(imgui.GetFontSize() * 1.5, 0)
                            local button_size = button.size or default_button_size
                            local button_id = button_text .. "##" .. id .. "_btn_" .. j .. "_" .. original_idx

                            if imgui.AnimButton(button_id, button_size) then
                                button.callback(row_data, original_idx)
                                data_changed = true
                            end

                            if button.color then
                                imgui.PopStyleColor(3)
                            end
                        end
                    end
                end
            end
        end

        imgui.EndTable()
    end

    if total_pages > 0 then
        imgui.Separator()
        imgui.AlignTextToFramePadding()
        imgui.TextColored(imgui.ImVec4(0.4, 0.7, 1.0, 1.0),
            string.format("Page %d of %d (%d total rows)", current_page, total_pages, #display_data))
    end

    if total_pages > 1 then
        imgui.SameLine()

        local pagination_buttons = {
            { "<<", 1,                current_page > 1 },
            { "<",  current_page - 1, current_page > 1 },
            { ">",  current_page + 1, current_page < total_pages },
            { ">>", total_pages,      current_page < total_pages }
        }

        local pagination_button_size = imgui.ImVec2(imgui.GetFontSize() * 2, 0)

        for i, btn in ipairs(pagination_buttons) do
            local label, target_page, enabled = btn[1], btn[2], btn[3]

            if enabled and imgui.AnimButton(label .. "##" .. id, pagination_button_size) then
                current_page = target_page
                storage:SetInt(current_page_key, current_page)
            elseif not enabled then
                imgui.PushStyleVar(imgui.StyleVar.Alpha, 0.5)
                imgui.AnimButton(label .. "##" .. id .. "_disabled", pagination_button_size)
                imgui.PopStyleVar()
            end

            if i < #pagination_buttons then
                imgui.SameLine()
            end
        end
    end
    return data_changed
end

function imgui.AnimButton(label, size)
    local duration = { 1.0, 0.3 }

    local cols = {
        default = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.Button]),
        hovered = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]),
        active  = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])
    }

    local storage = imgui.GetStateStorage()
    local color_x_key = imgui.GetID(label .. "_current_angle")
    local color_y_key = imgui.GetID(label .. "_current_angle_y")
    local color_z_key = imgui.GetID(label .. "_current_angle_z")
    local color_w_key = imgui.GetID(label .. "_current_angle_w")
    local clicked_start_key = imgui.GetID(label .. "_clicked_start")
    local clicked_end_key = imgui.GetID(label .. "_clicked_end")
    local hovered_cur_key = imgui.GetID(label .. "_hovered_cur")
    local hovered_old_key = imgui.GetID(label .. "_hovered_old")
    local hovered_clock_key = imgui.GetID(label .. "_hovered_clock")

    local color = imgui.ImVec4(
        storage:GetFloat(color_x_key, cols.default.x),
        storage:GetFloat(color_y_key, cols.default.y),
        storage:GetFloat(color_z_key, cols.default.z),
        storage:GetFloat(color_w_key, cols.default.w)
    )

    local clicked_start = storage:GetFloat(clicked_start_key, -1)
    local clicked_end = storage:GetFloat(clicked_end_key, -1)
    local hovered_cur = storage:GetInt(hovered_cur_key, 0) == 1
    local hovered_old = storage:GetInt(hovered_old_key, 0) == 1
    local hovered_clock = storage:GetFloat(hovered_clock_key, -1)

    if clicked_start ~= -1 and clicked_end ~= -1 then
        if os.clock() - clicked_start <= duration[2] then
            local t = math.min((os.clock() - clicked_start) / duration[2], 1.0)
            color = imgui.ImLerp(color, cols.active, t)
        elseif os.clock() - clicked_end <= duration[2] then
            local t = math.min((os.clock() - clicked_end) / duration[2], 1.0)
            local target = hovered_cur and cols.hovered or cols.default
            color = imgui.ImLerp(color, target, t)
        else

            storage:SetFloat(clicked_start_key, -1)
            storage:SetFloat(clicked_end_key, -1)
        end
    else

        if hovered_clock ~= -1 then
            if os.clock() - hovered_clock <= duration[1] then
                local t = math.min((os.clock() - hovered_clock) / duration[1], 1.0)
                local target = hovered_cur and cols.hovered or cols.default
                color = imgui.ImLerp(color, target, t)
            else
                color = hovered_cur and cols.hovered or cols.default
            end
        end
    end

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(color))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(color))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(color))
    local result = imgui.Button(label, size or imgui.ImVec2(0, 0))
    imgui.PopStyleColor(3)

    if result then
        storage:SetFloat(clicked_start_key, os.clock())
        storage:SetFloat(clicked_end_key, os.clock() + duration[2])
    end

    local new_hovered_cur = imgui.IsItemHovered()
    if hovered_old ~= new_hovered_cur then
        storage:SetInt(hovered_old_key, new_hovered_cur and 1 or 0)
        storage:SetFloat(hovered_clock_key, os.clock())
    end
    storage:SetInt(hovered_cur_key, new_hovered_cur and 1 or 0)

    storage:SetFloat(color_x_key, color.x)
    storage:SetFloat(color_y_key, color.y)
    storage:SetFloat(color_z_key, color.z)
    storage:SetFloat(color_w_key, color.w)

    return result
end

end

package.preload['src.utils.AsyncHttpRequest'] = function()
-- Sputnik asynchronous request API, using Windows' certificate-validated HTTPS.
local effil=require('effil')
local A={};A.__index=A
function A:new(method,url,args,timeout)
    local self=setmetatable({resolve=function() end,reject=function() end,finish=function() end},A)
    local task=effil.thread(function(url)
        local ffi=require('ffi')
        ffi.cdef[[
        int __stdcall MultiByteToWideChar(unsigned int,unsigned long,const char*,int,unsigned short*,int);
        void* __stdcall WinHttpOpen(const unsigned short*,unsigned long,const unsigned short*,const unsigned short*,unsigned long);
        void* __stdcall WinHttpConnect(void*,const unsigned short*,unsigned short,unsigned long);
        void* __stdcall WinHttpOpenRequest(void*,const unsigned short*,const unsigned short*,const unsigned short*,const unsigned short*,const unsigned short**,unsigned long);
        int __stdcall WinHttpSetTimeouts(void*,int,int,int,int);
        int __stdcall WinHttpSendRequest(void*,const unsigned short*,unsigned long,void*,unsigned long,unsigned long,uintptr_t);
        int __stdcall WinHttpReceiveResponse(void*,void*);
        int __stdcall WinHttpQueryHeaders(void*,unsigned long,const unsigned short*,void*,unsigned long*,unsigned long*);
        int __stdcall WinHttpReadData(void*,void*,unsigned long,unsigned long*);
        int __stdcall WinHttpCloseHandle(void*);
        ]]
        local w=ffi.load('winhttp');local k=ffi.load('kernel32')
        local function wide(s) local n=k.MultiByteToWideChar(65001,0,s,#s,nil,0);local b=ffi.new('unsigned short[?]',n+1);k.MultiByteToWideChar(65001,0,s,#s,b,n);return b end
        local host,route=url:match('^https://([^/]+)(/.*)$')
        if not host or host:find('[^%w.%-]') then return false,'Invalid HTTPS URL' end
        local handles={}
        local function close() for i=#handles,1,-1 do w.WinHttpCloseHandle(handles[i]) end end
        local ok,result=pcall(function()
            local session=w.WinHttpOpen(wide('LeoneMenu/1.0'),0,nil,nil,0);assert(session~=nil,'WinHTTP unavailable');handles[#handles+1]=session
            w.WinHttpSetTimeouts(session,5000,5000,10000,10000)
            local conn=w.WinHttpConnect(session,wide(host),443,0);assert(conn~=nil,'Connection failed');handles[#handles+1]=conn
            local req=w.WinHttpOpenRequest(conn,wide('GET'),wide(route),nil,nil,nil,0x00800000);assert(req~=nil,'Request failed');handles[#handles+1]=req
            assert(w.WinHttpSendRequest(req,nil,0,nil,0,0,0)~=0,'HTTPS send failed')
            assert(w.WinHttpReceiveResponse(req,nil)~=0,'HTTPS receive failed')
            local status=ffi.new('unsigned long[1]');local size=ffi.new('unsigned long[1]',4)
            assert(w.WinHttpQueryHeaders(req,0x20000013,nil,status,size,nil)~=0,'No HTTP status')
            local buf=ffi.new('char[32768]');local read=ffi.new('unsigned long[1]');local chunks={};local total=0
            repeat
                assert(w.WinHttpReadData(req,buf,32768,read)~=0,'HTTPS read failed')
                total=total+tonumber(read[0]);assert(total<=4194304,'Response exceeds 4 MB')
                chunks[#chunks+1]=ffi.string(buf,read[0])
            until read[0]==0
            return {status_code=tonumber(status[0]),text=table.concat(chunks)}
        end)
        close();return ok,result
    end)(url)
    lua_thread.create(function()
        local started=os.time()
        while true do
            local status=task:status()
            if status=='completed' then
                local ok,success,response=pcall(task.get,task)
                if ok and success then self.resolve(response) else self.reject(tostring(response or success)) end
                self.finish();break
            elseif status=='failed' or status=='canceled' or os.time()-started>(timeout or 20) then
                task:cancel();self.reject('HTTPS request failed or timed out');self.finish();break
            end
            wait(20)
        end
    end)
    return self
end
function A:then_(f) self.resolve=f;return self end
function A:catch(f) self.reject=f;return self end
function A:finally(f) self.finish=f;return self end
return A

end

package.preload['src.utils.ElementRealigner'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\utils\ElementRealigner.lua

local imgui = require("upmimgui")

local MainWindow = require("src.ui.MainWindow")

local _realigner_state = {
    is_realigning = imgui.new.bool(false),
    update_callback = nil,
    frame = nil,
    preview = nil,
    started = 0,
}

local function _get_normalized_cursor()
    local cursor = imgui.GetMousePos()
    local display_size = imgui.GetIO().DisplaySize
    if display_size.x<=0 or display_size.y<=0 then return nil end
    return math.max(0,math.min(0.98,cursor.x / display_size.x)), math.max(0,math.min(0.98,cursor.y / display_size.y))
end

local function _complete_realignment()
    MainWindow:show()

    _realigner_state.is_realigning[0] = false
    _realigner_state.update_callback = nil
    _realigner_state.preview = nil
    save_config()
end

local function _initialize_frame()
    if _realigner_state.frame then return end

    _realigner_state.frame = imgui.OnFrame(
        function() return _realigner_state.is_realigning[0] end,
        function()
            local normalized_x, normalized_y = _get_normalized_cursor()

            if normalized_x and _realigner_state.update_callback then
                _realigner_state.update_callback(normalized_x, normalized_y)
            end

            if os.clock()-_realigner_state.started>0.15 and imgui.IsMouseClicked(0, false) then
                _complete_realignment()
            end
        end
    )
    _realigner_state.frame.LockPlayer = true
end

_initialize_frame()

local ElementRealigner = {}

function ElementRealigner:realign_element(on_update, options)
    if _realigner_state.is_realigning[0] then
        _complete_realignment()
    end

    _realigner_state.started = os.clock()
    _realigner_state.preview = options and options.preview
    _realigner_state.update_callback = on_update
    _realigner_state.is_realigning[0] = true
    MainWindow:hide()
end

function ElementRealigner:is_preview(tag)
    return _realigner_state.is_realigning[0] and _realigner_state.preview==tag
end
function ElementRealigner:is_active()return _realigner_state.is_realigning[0] end
return ElementRealigner

end

package.preload['src.utils.Player'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\utils\Player.lua

local Player = {}

function Player:resolve_player_id(args,quiet)
    local players={}
    for id=0,sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then players[#players+1]={id=id,name=sampGetPlayerNickname(id)} end
    end
    local found=require('src.core.Rules').matches(args,players)
    if #found==1 then return found[1].id end
    if not quiet then
        if #found==0 then msg("Player isn't logged in or ID/name is wrong, try again")
        else
            msg('Several players match that name. Use their ID:')
            for _,p in ipairs(found) do msg(string.format('%s ({1E3348}%d{FFFFFF})',p.name:gsub('_',' '),p.id)) end
        end
    end
    return nil
end

function Player:get_closest_player_id(max_distance, filters)
    local closest_id, closest_distance = nil, max_distance
    local l_px, l_py, l_pz = getCharCoordinates(PLAYER_PED)
    for i = 0, sampGetMaxPlayerId(true) do
        local ok, ped = sampGetCharHandleBySampPlayerId(i)
        if ok then
            local passed = true
            if filters then
                for _, filter in ipairs(filters) do
                    if not filter(i, ped) then
                        passed = false
                        break
                    end
                end
            end
            if passed then
                local px, py, pz = getCharCoordinates(ped)
                if is_within_distance_3d(px, py, pz, l_px, l_py, l_pz, closest_distance) then
                    local dx = px - l_px
                    local dy = py - l_py
                    local dz = pz - l_pz
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                    if dist < closest_distance then
                        closest_id = i
                        closest_distance = dist
                    end
                end
            end
        end
    end
    return closest_id ~= nil, closest_id
end

function Player:get_player_id_by_name(player_name)
    local my_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))

    if player_name == sampGetPlayerNickname(my_id) then
        return my_id
    end

    for player_id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(player_id) then
            local name = sampGetPlayerNickname(player_id)
            if name == player_name then
                return player_id
            end
        end
    end
    return nil
end

function Player:is_on_admin_duty()
    local my_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local nickname = sampGetPlayerNickname(my_id)

    return not nickname:find("_")
end

function Player:is_valid_samp_name(name)
    local len = #name
    return len >= 3 and len <= 24
        and not name:find("%s")
        and name:find("_")
        and name:match("^[A-Za-z0-9_.]+$")
end

return Player

end

package.preload['src.utils.ZoneManager'] = function()
-- Module: F:\2025\EDrive\dev\luapack\src\utils\ZoneManager.lua
local ZONES = {
    { "Avispa Country Club",        -2667.810, -302.135,  -28.831,  -2646.400, -262.320,  71.169 },
    { "Easter Bay Airport",         -1315.420, -405.388,  15.406,   -1264.400, -209.543,  25.406 },
    { "Avispa Country Club",        -2550.040, -355.493,  0.000,    -2470.040, -318.493,  39.700 },
    { "Easter Bay Airport",         -1490.330, -209.543,  15.406,   -1264.400, -148.388,  25.406 },
    { "Garcia",                     -2395.140, -222.589,  -5.3,     -2354.090, -204.792,  200.000 },
    { "Shady Cabin",                -1632.830, -2263.440, -3.0,     -1601.330, -2231.790, 200.000 },
    { "East Los Santos",            2381.680,  -1494.030, -89.084,  2421.030,  -1454.350, 110.916 },
    { "LVA Freight Depot",          1236.630,  1163.410,  -89.084,  1277.050,  1203.280,  110.916 },
    { "Blackfield Intersection",    1277.050,  1044.690,  -89.084,  1315.350,  1087.630,  110.916 },
    { "Avispa Country Club",        -2470.040, -355.493,  0.000,    -2270.040, -318.493,  46.100 },
    { "Temple",                     1252.330,  -926.999,  -89.084,  1357.000,  -910.170,  110.916 },
    { "Unity Station",              1692.620,  -1971.800, -20.492,  1812.620,  -1932.800, 79.508 },
    { "LVA Freight Depot",          1315.350,  1044.690,  -89.084,  1375.600,  1087.630,  110.916 },
    { "Los Flores",                 2581.730,  -1454.350, -89.084,  2632.830,  -1393.420, 110.916 },
    { "Starfish Casino",            2437.390,  1858.100,  -39.084,  2495.090,  1970.850,  60.916 },
    { "Easter Bay Chemicals",       -1132.820, -787.391,  0.000,    -956.476,  -768.027,  200.000 },
    { "Downtown Los Santos",        1370.850,  -1170.870, -89.084,  1463.900,  -1130.850, 110.916 },
    { "Esplanade East",             -1620.300, 1176.520,  -4.5,     -1580.010, 1274.260,  200.000 },
    { "Market Station",             787.461,   -1410.930, -34.126,  866.009,   -1310.210, 65.874 },
    { "Linden Station",             2811.250,  1229.590,  -39.594,  2861.250,  1407.590,  60.406 },
    { "Montgomery Intersection",    1582.440,  347.457,   0.000,    1664.620,  401.750,   200.000 },
    { "Frederick Bridge",           2759.250,  296.501,   0.000,    2774.250,  594.757,   200.000 },
    { "Yellow Bell Station",        1377.480,  2600.430,  -21.926,  1492.450,  2687.360,  78.074 },
    { "Downtown Los Santos",        1507.510,  -1385.210, 110.916,  1582.550,  -1325.310, 335.916 },
    { "Jefferson",                  2185.330,  -1210.740, -89.084,  2281.450,  -1154.590, 110.916 },
    { "Mulholland",                 1318.130,  -910.170,  -89.084,  1357.000,  -768.027,  110.916 },
    { "Avispa Country Club",        -2361.510, -417.199,  0.000,    -2270.040, -355.493,  200.000 },
    { "Jefferson",                  1996.910,  -1449.670, -89.084,  2056.860,  -1350.720, 110.916 },
    { "Julius Thruway West",        1236.630,  2142.860,  -89.084,  1297.470,  2243.230,  110.916 },
    { "Jefferson",                  2124.660,  -1494.030, -89.084,  2266.210,  -1449.670, 110.916 },
    { "Julius Thruway North",       1848.400,  2478.490,  -89.084,  1938.800,  2553.490,  110.916 },
    { "Rodeo",                      422.680,   -1570.200, -89.084,  466.223,   -1406.050, 110.916 },
    { "Cranberry Station",          -2007.830, 56.306,    0.000,    -1922.000, 224.782,   100.000 },
    { "Downtown Los Santos",        1391.050,  -1026.330, -89.084,  1463.900,  -926.999,  110.916 },
    { "Redsands West",              1704.590,  2243.230,  -89.084,  1777.390,  2342.830,  110.916 },
    { "Little Mexico",              1758.900,  -1722.260, -89.084,  1812.620,  -1577.590, 110.916 },
    { "Blackfield Intersection",    1375.600,  823.228,   -89.084,  1457.390,  919.447,   110.916 },
    { "Los Santos International",   1974.630,  -2394.330, -39.084,  2089.000,  -2256.590, 60.916 },
    { "Beacon Hill",                -399.633,  -1075.520, -1.489,   -319.033,  -977.516,  198.511 },
    { "Rodeo",                      334.503,   -1501.950, -89.084,  422.680,   -1406.050, 110.916 },
    { "Richman",                    225.165,   -1369.620, -89.084,  334.503,   -1292.070, 110.916 },
    { "Downtown Los Santos",        1724.760,  -1250.900, -89.084,  1812.620,  -1150.870, 110.916 },
    { "The Strip",                  2027.400,  1703.230,  -89.084,  2137.400,  1783.230,  110.916 },
    { "Downtown Los Santos",        1378.330,  -1130.850, -89.084,  1463.900,  -1026.330, 110.916 },
    { "Blackfield Intersection",    1197.390,  1044.690,  -89.084,  1277.050,  1163.390,  110.916 },
    { "Conference Center",          1073.220,  -1842.270, -89.084,  1323.900,  -1804.210, 110.916 },
    { "Montgomery",                 1451.400,  347.457,   -6.1,     1582.440,  420.802,   200.000 },
    { "Foster Valley",              -2270.040, -430.276,  -1.2,     -2178.690, -324.114,  200.000 },
    { "Blackfield Chapel",          1325.600,  596.349,   -89.084,  1375.600,  795.010,   110.916 },
    { "Los Santos International",   2051.630,  -2597.260, -39.084,  2152.450,  -2394.330, 60.916 },
    { "Mulholland",                 1096.470,  -910.170,  -89.084,  1169.130,  -768.027,  110.916 },
    { "Yellow Bell Gol Course",     1457.460,  2723.230,  -89.084,  1534.560,  2863.230,  110.916 },
    { "The Strip",                  2027.400,  1783.230,  -89.084,  2162.390,  1863.230,  110.916 },
    { "Jefferson",                  2056.860,  -1210.740, -89.084,  2185.330,  -1126.320, 110.916 },
    { "Mulholland",                 952.604,   -937.184,  -89.084,  1096.470,  -860.619,  110.916 },
    { "Aldea Malvada",              -1372.140, 2498.520,  0.000,    -1277.590, 2615.350,  200.000 },
    { "Las Colinas",                2126.860,  -1126.320, -89.084,  2185.330,  -934.489,  110.916 },
    { "Las Colinas",                1994.330,  -1100.820, -89.084,  2056.860,  -920.815,  110.916 },
    { "Richman",                    647.557,   -954.662,  -89.084,  768.694,   -860.619,  110.916 },
    { "LVA Freight Depot",          1277.050,  1087.630,  -89.084,  1375.600,  1203.280,  110.916 },
    { "Julius Thruway North",       1377.390,  2433.230,  -89.084,  1534.560,  2507.230,  110.916 },
    { "Willowfield",                2201.820,  -2095.000, -89.084,  2324.000,  -1989.900, 110.916 },
    { "Julius Thruway North",       1704.590,  2342.830,  -89.084,  1848.400,  2433.230,  110.916 },
    { "Temple",                     1252.330,  -1130.850, -89.084,  1378.330,  -1026.330, 110.916 },
    { "Little Mexico",              1701.900,  -1842.270, -89.084,  1812.620,  -1722.260, 110.916 },
    { "Queens",                     -2411.220, 373.539,   0.000,    -2253.540, 458.411,   200.000 },
    { "Las Venturas Airport",       1515.810,  1586.400,  -12.500,  1729.950,  1714.560,  87.500 },
    { "Richman",                    225.165,   -1292.070, -89.084,  466.223,   -1235.070, 110.916 },
    { "Temple",                     1252.330,  -1026.330, -89.084,  1391.050,  -926.999,  110.916 },
    { "East Los Santos",            2266.260,  -1494.030, -89.084,  2381.680,  -1372.040, 110.916 },
    { "Julius Thruway East",        2623.180,  943.235,   -89.084,  2749.900,  1055.960,  110.916 },
    { "Willowfield",                2541.700,  -1941.400, -89.084,  2703.580,  -1852.870, 110.916 },
    { "Las Colinas",                2056.860,  -1126.320, -89.084,  2126.860,  -920.815,  110.916 },
    { "Julius Thruway East",        2625.160,  2202.760,  -89.084,  2685.160,  2442.550,  110.916 },
    { "Rodeo",                      225.165,   -1501.950, -89.084,  334.503,   -1369.620, 110.916 },
    { "Las Brujas",                 -365.167,  2123.010,  -3.0,     -208.570,  2217.680,  200.000 },
    { "Julius Thruway East",        2536.430,  2442.550,  -89.084,  2685.160,  2542.550,  110.916 },
    { "Rodeo",                      334.503,   -1406.050, -89.084,  466.223,   -1292.070, 110.916 },
    { "Vinewood",                   647.557,   -1227.280, -89.084,  787.461,   -1118.280, 110.916 },
    { "Rodeo",                      422.680,   -1684.650, -89.084,  558.099,   -1570.200, 110.916 },
    { "Julius Thruway North",       2498.210,  2542.550,  -89.084,  2685.160,  2626.550,  110.916 },
    { "Downtown Los Santos",        1724.760,  -1430.870, -89.084,  1812.620,  -1250.900, 110.916 },
    { "Rodeo",                      225.165,   -1684.650, -89.084,  312.803,   -1501.950, 110.916 },
    { "Jefferson",                  2056.860,  -1449.670, -89.084,  2266.210,  -1372.040, 110.916 },
    { "Hampton Barns",              603.035,   264.312,   0.000,    761.994,   366.572,   200.000 },
    { "Temple",                     1096.470,  -1130.840, -89.084,  1252.330,  -1026.330, 110.916 },
    { "Kincaid Bridge",             -1087.930, 855.370,   -89.084,  -961.950,  986.281,   110.916 },
    { "Verona Beach",               1046.150,  -1722.260, -89.084,  1161.520,  -1577.590, 110.916 },
    { "Commerce",                   1323.900,  -1722.260, -89.084,  1440.900,  -1577.590, 110.916 },
    { "Mulholland",                 1357.000,  -926.999,  -89.084,  1463.900,  -768.027,  110.916 },
    { "Rodeo",                      466.223,   -1570.200, -89.084,  558.099,   -1385.070, 110.916 },
    { "Mulholland",                 911.802,   -860.619,  -89.084,  1096.470,  -768.027,  110.916 },
    { "Mulholland",                 768.694,   -954.662,  -89.084,  952.604,   -860.619,  110.916 },
    { "Julius Thruway South",       2377.390,  788.894,   -89.084,  2537.390,  897.901,   110.916 },
    { "Idlewood",                   1812.620,  -1852.870, -89.084,  1971.660,  -1742.310, 110.916 },
    { "Ocean Docks",                2089.000,  -2394.330, -89.084,  2201.820,  -2235.840, 110.916 },
    { "Commerce",                   1370.850,  -1577.590, -89.084,  1463.900,  -1384.950, 110.916 },
    { "Julius Thruway North",       2121.400,  2508.230,  -89.084,  2237.400,  2663.170,  110.916 },
    { "Temple",                     1096.470,  -1026.330, -89.084,  1252.330,  -910.170,  110.916 },
    { "Glen Park",                  1812.620,  -1449.670, -89.084,  1996.910,  -1350.720, 110.916 },
    { "Easter Bay Airport",         -1242.980, -50.096,   0.000,    -1213.910, 578.396,   200.000 },
    { "Martin Bridge",              -222.179,  293.324,   0.000,    -122.126,  476.465,   200.000 },
    { "The Strip",                  2106.700,  1863.230,  -89.084,  2162.390,  2202.760,  110.916 },
    { "Willowfield",                2541.700,  -2059.230, -89.084,  2703.580,  -1941.400, 110.916 },
    { "Marina",                     807.922,   -1577.590, -89.084,  926.922,   -1416.250, 110.916 },
    { "Las Venturas Airport",       1457.370,  1143.210,  -89.084,  1777.400,  1203.280,  110.916 },
    { "Idlewood",                   1812.620,  -1742.310, -89.084,  1951.660,  -1602.310, 110.916 },
    { "Esplanade East",             -1580.010, 1025.980,  -6.1,     -1499.890, 1274.260,  200.000 },
    { "Downtown Los Santos",        1370.850,  -1384.950, -89.084,  1463.900,  -1170.870, 110.916 },
    { "The Mako Span",              1664.620,  401.750,   0.000,    1785.140,  567.203,   200.000 },
    { "Rodeo",                      312.803,   -1684.650, -89.084,  422.680,   -1501.950, 110.916 },
    { "Pershing Square",            1440.900,  -1722.260, -89.084,  1583.500,  -1577.590, 110.916 },
    { "Mulholland",                 687.802,   -860.619,  -89.084,  911.802,   -768.027,  110.916 },
    { "Gant Bridge",                -2741.070, 1490.470,  -6.1,     -2616.400, 1659.680,  200.000 },
    { "Las Colinas",                2185.330,  -1154.590, -89.084,  2281.450,  -934.489,  110.916 },
    { "Mulholland",                 1169.130,  -910.170,  -89.084,  1318.130,  -768.027,  110.916 },
    { "Julius Thruway North",       1938.800,  2508.230,  -89.084,  2121.400,  2624.230,  110.916 },
    { "Commerce",                   1667.960,  -1577.590, -89.084,  1812.620,  -1430.870, 110.916 },
    { "Rodeo",                      72.648,    -1544.170, -89.084,  225.165,   -1404.970, 110.916 },
    { "Roca Escalante",             2536.430,  2202.760,  -89.084,  2625.160,  2442.550,  110.916 },
    { "Rodeo",                      72.648,    -1684.650, -89.084,  225.165,   -1544.170, 110.916 },
    { "Market",                     952.663,   -1310.210, -89.084,  1072.660,  -1130.850, 110.916 },
    { "Las Colinas",                2632.740,  -1135.040, -89.084,  2747.740,  -945.035,  110.916 },
    { "Mulholland",                 861.085,   -674.885,  -89.084,  1156.550,  -600.896,  110.916 },
    { "King's",                     -2253.540, 373.539,   -9.1,     -1993.280, 458.411,   200.000 },
    { "Redsands East",              1848.400,  2342.830,  -89.084,  2011.940,  2478.490,  110.916 },
    { "Downtown",                   -1580.010, 744.267,   -6.1,     -1499.890, 1025.980,  200.000 },
    { "Conference Center",          1046.150,  -1804.210, -89.084,  1323.900,  -1722.260, 110.916 },
    { "Richman",                    647.557,   -1118.280, -89.084,  787.461,   -954.662,  110.916 },
    { "Ocean Flats",                -2994.490, 277.411,   -9.1,     -2867.850, 458.411,   200.000 },
    { "Greenglass College",         964.391,   930.890,   -89.084,  1166.530,  1044.690,  110.916 },
    { "Glen Park",                  1812.620,  -1100.820, -89.084,  1994.330,  -973.380,  110.916 },
    { "LVA Freight Depot",          1375.600,  919.447,   -89.084,  1457.370,  1203.280,  110.916 },
    { "Regular Tom",                -405.770,  1712.860,  -3.0,     -276.719,  1892.750,  200.000 },
    { "Verona Beach",               1161.520,  -1722.260, -89.084,  1323.900,  -1577.590, 110.916 },
    { "East Los Santos",            2281.450,  -1372.040, -89.084,  2381.680,  -1135.040, 110.916 },
    { "Caligula's Palace",          2137.400,  1703.230,  -89.084,  2437.390,  1783.230,  110.916 },
    { "Idlewood",                   1951.660,  -1742.310, -89.084,  2124.660,  -1602.310, 110.916 },
    { "Pilgrim",                    2624.400,  1383.230,  -89.084,  2685.160,  1783.230,  110.916 },
    { "Idlewood",                   2124.660,  -1742.310, -89.084,  2222.560,  -1494.030, 110.916 },
    { "Queens",                     -2533.040, 458.411,   0.000,    -2329.310, 578.396,   200.000 },
    { "Downtown",                   -1871.720, 1176.420,  -4.5,     -1620.300, 1274.260,  200.000 },
    { "Commerce",                   1583.500,  -1722.260, -89.084,  1758.900,  -1577.590, 110.916 },
    { "East Los Santos",            2381.680,  -1454.350, -89.084,  2462.130,  -1135.040, 110.916 },
    { "Marina",                     647.712,   -1577.590, -89.084,  807.922,   -1416.250, 110.916 },
    { "Richman",                    72.648,    -1404.970, -89.084,  225.165,   -1235.070, 110.916 },
    { "Vinewood",                   647.712,   -1416.250, -89.084,  787.461,   -1227.280, 110.916 },
    { "East Los Santos",            2222.560,  -1628.530, -89.084,  2421.030,  -1494.030, 110.916 },
    { "Rodeo",                      558.099,   -1684.650, -89.084,  647.522,   -1384.930, 110.916 },
    { "Easter Tunnel",              -1709.710, -833.034,  -1.5,     -1446.010, -730.118,  200.000 },
    { "Rodeo",                      466.223,   -1385.070, -89.084,  647.522,   -1235.070, 110.916 },
    { "Redsands East",              1817.390,  2202.760,  -89.084,  2011.940,  2342.830,  110.916 },
    { "The Clown's Pocket",         2162.390,  1783.230,  -89.084,  2437.390,  1883.230,  110.916 },
    { "Idlewood",                   1971.660,  -1852.870, -89.084,  2222.560,  -1742.310, 110.916 },
    { "Montgomery Intersection",    1546.650,  208.164,   0.000,    1745.830,  347.457,   200.000 },
    { "Willowfield",                2089.000,  -2235.840, -89.084,  2201.820,  -1989.900, 110.916 },
    { "Temple",                     952.663,   -1130.840, -89.084,  1096.470,  -937.184,  110.916 },
    { "Prickle Pine",               1848.400,  2553.490,  -89.084,  1938.800,  2863.230,  110.916 },
    { "Los Santos International",   1400.970,  -2669.260, -39.084,  2189.820,  -2597.260, 60.916 },
    { "Garver Bridge",              -1213.910, 950.022,   -89.084,  -1087.930, 1178.930,  110.916 },
    { "Garver Bridge",              -1339.890, 828.129,   -89.084,  -1213.910, 1057.040,  110.916 },
    { "Kincaid Bridge",             -1339.890, 599.218,   -89.084,  -1213.910, 828.129,   110.916 },
    { "Kincaid Bridge",             -1213.910, 721.111,   -89.084,  -1087.930, 950.022,   110.916 },
    { "Verona Beach",               930.221,   -2006.780, -89.084,  1073.220,  -1804.210, 110.916 },
    { "Verdant Bluffs",             1073.220,  -2006.780, -89.084,  1249.620,  -1842.270, 110.916 },
    { "Vinewood",                   787.461,   -1130.840, -89.084,  952.604,   -954.662,  110.916 },
    { "Vinewood",                   787.461,   -1310.210, -89.084,  952.663,   -1130.840, 110.916 },
    { "Commerce",                   1463.900,  -1577.590, -89.084,  1667.960,  -1430.870, 110.916 },
    { "Market",                     787.461,   -1416.250, -89.084,  1072.660,  -1310.210, 110.916 },
    { "Rockshore West",             2377.390,  596.349,   -89.084,  2537.390,  788.894,   110.916 },
    { "Julius Thruway North",       2237.400,  2542.550,  -89.084,  2498.210,  2663.170,  110.916 },
    { "East Beach",                 2632.830,  -1668.130, -89.084,  2747.740,  -1393.420, 110.916 },
    { "Fallow Bridge",              434.341,   366.572,   0.000,    603.035,   555.680,   200.000 },
    { "Willowfield",                2089.000,  -1989.900, -89.084,  2324.000,  -1852.870, 110.916 },
    { "Chinatown",                  -2274.170, 578.396,   -7.6,     -2078.670, 744.170,   200.000 },
    { "El Castillo del Diablo",     -208.570,  2337.180,  0.000,    8.430,     2487.180,  200.000 },
    { "Ocean Docks",                2324.000,  -2145.100, -89.084,  2703.580,  -2059.230, 110.916 },
    { "Easter Bay Chemicals",       -1132.820, -768.027,  0.000,    -956.476,  -578.118,  200.000 },
    { "The Visage",                 1817.390,  1703.230,  -89.084,  2027.400,  1863.230,  110.916 },
    { "Ocean Flats",                -2994.490, -430.276,  -1.2,     -2831.890, -222.589,  200.000 },
    { "Richman",                    321.356,   -860.619,  -89.084,  687.802,   -768.027,  110.916 },
    { "Green Palms",                176.581,   1305.450,  -3.0,     338.658,   1520.720,  200.000 },
    { "Richman",                    321.356,   -768.027,  -89.084,  700.794,   -674.885,  110.916 },
    { "Starfish Casino",            2162.390,  1883.230,  -89.084,  2437.390,  2012.180,  110.916 },
    { "East Beach",                 2747.740,  -1668.130, -89.084,  2959.350,  -1498.620, 110.916 },
    { "Jefferson",                  2056.860,  -1372.040, -89.084,  2281.450,  -1210.740, 110.916 },
    { "Downtown Los Santos",        1463.900,  -1290.870, -89.084,  1724.760,  -1150.870, 110.916 },
    { "Downtown Los Santos",        1463.900,  -1430.870, -89.084,  1724.760,  -1290.870, 110.916 },
    { "Garver Bridge",              -1499.890, 696.442,   -179.615, -1339.890, 925.353,   20.385 },
    { "Julius Thruway South",       1457.390,  823.228,   -89.084,  2377.390,  863.229,   110.916 },
    { "East Los Santos",            2421.030,  -1628.530, -89.084,  2632.830,  -1454.350, 110.916 },
    { "Greenglass College",         964.391,   1044.690,  -89.084,  1197.390,  1203.220,  110.916 },
    { "Las Colinas",                2747.740,  -1120.040, -89.084,  2959.350,  -945.035,  110.916 },
    { "Mulholland",                 737.573,   -768.027,  -89.084,  1142.290,  -674.885,  110.916 },
    { "Ocean Docks",                2201.820,  -2730.880, -89.084,  2324.000,  -2418.330, 110.916 },
    { "East Los Santos",            2462.130,  -1454.350, -89.084,  2581.730,  -1135.040, 110.916 },
    { "Ganton",                     2222.560,  -1722.330, -89.084,  2632.830,  -1628.530, 110.916 },
    { "Avispa Country Club",        -2831.890, -430.276,  -6.1,     -2646.400, -222.589,  200.000 },
    { "Willowfield",                1970.620,  -2179.250, -89.084,  2089.000,  -1852.870, 110.916 },
    { "Esplanade North",            -1982.320, 1274.260,  -4.5,     -1524.240, 1358.900,  200.000 },
    { "The High Roller",            1817.390,  1283.230,  -89.084,  2027.390,  1469.230,  110.916 },
    { "Ocean Docks",                2201.820,  -2418.330, -89.084,  2324.000,  -2095.000, 110.916 },
    { "Last Dime Motel",            1823.080,  596.349,   -89.084,  1997.220,  823.228,   110.916 },
    { "Bayside Marina",             -2353.170, 2275.790,  0.000,    -2153.170, 2475.790,  200.000 },
    { "King's",                     -2329.310, 458.411,   -7.6,     -1993.280, 578.396,   200.000 },
    { "El Corona",                  1692.620,  -2179.250, -89.084,  1812.620,  -1842.270, 110.916 },
    { "Blackfield Chapel",          1375.600,  596.349,   -89.084,  1558.090,  823.228,   110.916 },
    { "The Pink Swan",              1817.390,  1083.230,  -89.084,  2027.390,  1283.230,  110.916 },
    { "Julius Thruway West",        1197.390,  1163.390,  -89.084,  1236.630,  2243.230,  110.916 },
    { "Los Flores",                 2581.730,  -1393.420, -89.084,  2747.740,  -1135.040, 110.916 },
    { "The Visage",                 1817.390,  1863.230,  -89.084,  2106.700,  2011.830,  110.916 },
    { "Prickle Pine",               1938.800,  2624.230,  -89.084,  2121.400,  2861.550,  110.916 },
    { "Verona Beach",               851.449,   -1804.210, -89.084,  1046.150,  -1577.590, 110.916 },
    { "Robada Intersection",        -1119.010, 1178.930,  -89.084,  -862.025,  1351.450,  110.916 },
    { "Linden Side",                2749.900,  943.235,   -89.084,  2923.390,  1198.990,  110.916 },
    { "Ocean Docks",                2703.580,  -2302.330, -89.084,  2959.350,  -2126.900, 110.916 },
    { "Willowfield",                2324.000,  -2059.230, -89.084,  2541.700,  -1852.870, 110.916 },
    { "King's",                     -2411.220, 265.243,   -9.1,     -1993.280, 373.539,   200.000 },
    { "Commerce",                   1323.900,  -1842.270, -89.084,  1701.900,  -1722.260, 110.916 },
    { "Mulholland",                 1269.130,  -768.027,  -89.084,  1414.070,  -452.425,  110.916 },
    { "Marina",                     647.712,   -1804.210, -89.084,  851.449,   -1577.590, 110.916 },
    { "Battery Point",              -2741.070, 1268.410,  -4.5,     -2533.040, 1490.470,  200.000 },
    { "The Four Dragons Casino",    1817.390,  863.232,   -89.084,  2027.390,  1083.230,  110.916 },
    { "Blackfield",                 964.391,   1203.220,  -89.084,  1197.390,  1403.220,  110.916 },
    { "Julius Thruway North",       1534.560,  2433.230,  -89.084,  1848.400,  2583.230,  110.916 },
    { "Yellow Bell Gol Course",     1117.400,  2723.230,  -89.084,  1457.460,  2863.230,  110.916 },
    { "Idlewood",                   1812.620,  -1602.310, -89.084,  2124.660,  -1449.670, 110.916 },
    { "Redsands West",              1297.470,  2142.860,  -89.084,  1777.390,  2243.230,  110.916 },
    { "Doherty",                    -2270.040, -324.114,  -1.2,     -1794.920, -222.589,  200.000 },
    { "Hilltop Farm",               967.383,   -450.390,  -3.0,     1176.780,  -217.900,  200.000 },
    { "Las Barrancas",              -926.130,  1398.730,  -3.0,     -719.234,  1634.690,  200.000 },
    { "Pirates in Men's Pants",     1817.390,  1469.230,  -89.084,  2027.400,  1703.230,  110.916 },
    { "City Hall",                  -2867.850, 277.411,   -9.1,     -2593.440, 458.411,   200.000 },
    { "Avispa Country Club",        -2646.400, -355.493,  0.000,    -2270.040, -222.589,  200.000 },
    { "The Strip",                  2027.400,  863.229,   -89.084,  2087.390,  1703.230,  110.916 },
    { "Hashbury",                   -2593.440, -222.589,  -1.0,     -2411.220, 54.722,    200.000 },
    { "Los Santos International",   1852.000,  -2394.330, -89.084,  2089.000,  -2179.250, 110.916 },
    { "Whitewood Estates",          1098.310,  1726.220,  -89.084,  1197.390,  2243.230,  110.916 },
    { "Sherman Reservoir",          -789.737,  1659.680,  -89.084,  -599.505,  1929.410,  110.916 },
    { "El Corona",                  1812.620,  -2179.250, -89.084,  1970.620,  -1852.870, 110.916 },
    { "Downtown",                   -1700.010, 744.267,   -6.1,     -1580.010, 1176.520,  200.000 },
    { "Foster Valley",              -2178.690, -1250.970, 0.000,    -1794.920, -1115.580, 200.000 },
    { "Las Payasadas",              -354.332,  2580.360,  2.0,      -133.625,  2816.820,  200.000 },
    { "Valle Ocultado",             -936.668,  2611.440,  2.0,      -715.961,  2847.900,  200.000 },
    { "Blackfield Intersection",    1166.530,  795.010,   -89.084,  1375.600,  1044.690,  110.916 },
    { "Ganton",                     2222.560,  -1852.870, -89.084,  2632.830,  -1722.330, 110.916 },
    { "Easter Bay Airport",         -1213.910, -730.118,  0.000,    -1132.820, -50.096,   200.000 },
    { "Redsands East",              1817.390,  2011.830,  -89.084,  2106.700,  2202.760,  110.916 },
    { "Esplanade East",             -1499.890, 578.396,   -79.615,  -1339.890, 1274.260,  20.385 },
    { "Caligula's Palace",          2087.390,  1543.230,  -89.084,  2437.390,  1703.230,  110.916 },
    { "Royal Casino",               2087.390,  1383.230,  -89.084,  2437.390,  1543.230,  110.916 },
    { "Richman",                    72.648,    -1235.070, -89.084,  321.356,   -1008.150, 110.916 },
    { "Starfish Casino",            2437.390,  1783.230,  -89.084,  2685.160,  2012.180,  110.916 },
    { "Mulholland",                 1281.130,  -452.425,  -89.084,  1641.130,  -290.913,  110.916 },
    { "Downtown",                   -1982.320, 744.170,   -6.1,     -1871.720, 1274.260,  200.000 },
    { "Hankypanky Point",           2576.920,  62.158,    0.000,    2759.250,  385.503,   200.000 },
    { "K.A.C.C. Military Fuels",    2498.210,  2626.550,  -89.084,  2749.900,  2861.550,  110.916 },
    { "Harry Gold Parkway",         1777.390,  863.232,   -89.084,  1817.390,  2342.830,  110.916 },
    { "Bayside Tunnel",             -2290.190, 2548.290,  -89.084,  -1950.190, 2723.290,  110.916 },
    { "Ocean Docks",                2324.000,  -2302.330, -89.084,  2703.580,  -2145.100, 110.916 },
    { "Richman",                    321.356,   -1044.070, -89.084,  647.557,   -860.619,  110.916 },
    { "Randolph Industrial Estate", 1558.090,  596.349,   -89.084,  1823.080,  823.235,   110.916 },
    { "East Beach",                 2632.830,  -1852.870, -89.084,  2959.350,  -1668.130, 110.916 },
    { "Flint Water",                -314.426,  -753.874,  -89.084,  -106.339,  -463.073,  110.916 },
    { "Blueberry",                  19.607,    -404.136,  3.8,      349.607,   -220.137,  200.000 },
    { "Linden Station",             2749.900,  1198.990,  -89.084,  2923.390,  1548.990,  110.916 },
    { "Glen Park",                  1812.620,  -1350.720, -89.084,  2056.860,  -1100.820, 110.916 },
    { "Downtown",                   -1993.280, 265.243,   -9.1,     -1794.920, 578.396,   200.000 },
    { "Redsands West",              1377.390,  2243.230,  -89.084,  1704.590,  2433.230,  110.916 },
    { "Richman",                    321.356,   -1235.070, -89.084,  647.522,   -1044.070, 110.916 },
    { "Gant Bridge",                -2741.450, 1659.680,  -6.1,     -2616.400, 2175.150,  200.000 },
    { "Lil' Probe Inn",             -90.218,   1286.850,  -3.0,     153.859,   1554.120,  200.000 },
    { "Flint Intersection",         -187.700,  -1596.760, -89.084,  17.063,    -1276.600, 110.916 },
    { "Las Colinas",                2281.450,  -1135.040, -89.084,  2632.740,  -945.035,  110.916 },
    { "Sobell Rail Yards",          2749.900,  1548.990,  -89.084,  2923.390,  1937.250,  110.916 },
    { "The Emerald Isle",           2011.940,  2202.760,  -89.084,  2237.400,  2508.230,  110.916 },
    { "El Castillo del Diablo",     -208.570,  2123.010,  -7.6,     114.033,   2337.180,  200.000 },
    { "Santa Flora",                -2741.070, 458.411,   -7.6,     -2533.040, 793.411,   200.000 },
    { "Playa del Seville",          2703.580,  -2126.900, -89.084,  2959.350,  -1852.870, 110.916 },
    { "Market",                     926.922,   -1577.590, -89.084,  1370.850,  -1416.250, 110.916 },
    { "Queens",                     -2593.440, 54.722,    0.000,    -2411.220, 458.411,   200.000 },
    { "Pilson Intersection",        1098.390,  2243.230,  -89.084,  1377.390,  2507.230,  110.916 },
    { "Spinybed",                   2121.400,  2663.170,  -89.084,  2498.210,  2861.550,  110.916 },
    { "Pilgrim",                    2437.390,  1383.230,  -89.084,  2624.400,  1783.230,  110.916 },
    { "Blackfield",                 964.391,   1403.220,  -89.084,  1197.390,  1726.220,  110.916 },
    { "'The Big Ear'",              -410.020,  1403.340,  -3.0,     -137.969,  1681.230,  200.000 },
    { "Dillimore",                  580.794,   -674.885,  -9.5,     861.085,   -404.790,  200.000 },
    { "El Quebrados",               -1645.230, 2498.520,  0.000,    -1372.140, 2777.850,  200.000 },
    { "Esplanade North",            -2533.040, 1358.900,  -4.5,     -1996.660, 1501.210,  200.000 },
    { "Easter Bay Airport",         -1499.890, -50.096,   -1.0,     -1242.980, 249.904,   200.000 },
    { "Fisher's Lagoon",            1916.990,  -233.323,  -100.000, 2131.720,  13.800,    200.000 },
    { "Mulholland",                 1414.070,  -768.027,  -89.084,  1667.610,  -452.425,  110.916 },
    { "East Beach",                 2747.740,  -1498.620, -89.084,  2959.350,  -1120.040, 110.916 },
    { "San Andreas Sound",          2450.390,  385.503,   -100.000, 2759.250,  562.349,   200.000 },
    { "Shady Creeks",               -2030.120, -2174.890, -6.1,     -1820.640, -1771.660, 200.000 },
    { "Market",                     1072.660,  -1416.250, -89.084,  1370.850,  -1130.850, 110.916 },
    { "Rockshore West",             1997.220,  596.349,   -89.084,  2377.390,  823.228,   110.916 },
    { "Prickle Pine",               1534.560,  2583.230,  -89.084,  1848.400,  2863.230,  110.916 },
    { "Easter Basin",               -1794.920, -50.096,   -1.04,    -1499.890, 249.904,   200.000 },
    { "Leafy Hollow",               -1166.970, -1856.030, 0.000,    -815.624,  -1602.070, 200.000 },
    { "LVA Freight Depot",          1457.390,  863.229,   -89.084,  1777.400,  1143.210,  110.916 },
    { "Prickle Pine",               1117.400,  2507.230,  -89.084,  1534.560,  2723.230,  110.916 },
    { "Blueberry",                  104.534,   -220.137,  2.3,      349.607,   152.236,   200.000 },
    { "El Castillo del Diablo",     -464.515,  2217.680,  0.000,    -208.570,  2580.360,  200.000 },
    { "Downtown",                   -2078.670, 578.396,   -7.6,     -1499.890, 744.267,   200.000 },
    { "Rockshore East",             2537.390,  676.549,   -89.084,  2902.350,  943.235,   110.916 },
    { "San Fierro Bay",             -2616.400, 1501.210,  -3.0,     -1996.660, 1659.680,  200.000 },
    { "Paradiso",                   -2741.070, 793.411,   -6.1,     -2533.040, 1268.410,  200.000 },
    { "The Camel's Toe",            2087.390,  1203.230,  -89.084,  2640.400,  1383.230,  110.916 },
    { "Old Venturas Strip",         2162.390,  2012.180,  -89.084,  2685.160,  2202.760,  110.916 },
    { "Juniper Hill",               -2533.040, 578.396,   -7.6,     -2274.170, 968.369,   200.000 },
    { "Juniper Hollow",             -2533.040, 968.369,   -6.1,     -2274.170, 1358.900,  200.000 },
    { "Roca Escalante",             2237.400,  2202.760,  -89.084,  2536.430,  2542.550,  110.916 },
    { "Julius Thruway East",        2685.160,  1055.960,  -89.084,  2749.900,  2626.550,  110.916 },
    { "Verona Beach",               647.712,   -2173.290, -89.084,  930.221,   -1804.210, 110.916 },
    { "Foster Valley",              -2178.690, -599.884,  -1.2,     -1794.920, -324.114,  200.000 },
    { "Arco del Oeste",             -901.129,  2221.860,  0.000,    -592.090,  2571.970,  200.000 },
    { "Fallen Tree",                -792.254,  -698.555,  -5.3,     -452.404,  -380.043,  200.000 },
    { "The Farm",                   -1209.670, -1317.100, 114.981,  -908.161,  -787.391,  251.981 },
    { "The Sherman Dam",            -968.772,  1929.410,  -3.0,     -481.126,  2155.260,  200.000 },
    { "Esplanade North",            -1996.660, 1358.900,  -4.5,     -1524.240, 1592.510,  200.000 },
    { "Financial",                  -1871.720, 744.170,   -6.1,     -1701.300, 1176.420,  300.000 },
    { "Garcia",                     -2411.220, -222.589,  -1.14,    -2173.040, 265.243,   200.000 },
    { "Montgomery",                 1119.510,  119.526,   -3.0,     1451.400,  493.323,   200.000 },
    { "Creek",                      2749.900,  1937.250,  -89.084,  2921.620,  2669.790,  110.916 },
    { "Los Santos International",   1249.620,  -2394.330, -89.084,  1852.000,  -2179.250, 110.916 },
    { "Santa Maria Beach",          72.648,    -2173.290, -89.084,  342.648,   -1684.650, 110.916 },
    { "Mulholland Intersection",    1463.900,  -1150.870, -89.084,  1812.620,  -768.027,  110.916 },
    { "Angel Pine",                 -2324.940, -2584.290, -6.1,     -1964.220, -2212.110, 200.000 },
    { "Verdant Meadows",            37.032,    2337.180,  -3.0,     435.988,   2677.900,  200.000 },
    { "Octane Springs",             338.658,   1228.510,  0.000,    664.308,   1655.050,  200.000 },
    { "Come-A-Lot",                 2087.390,  943.235,   -89.084,  2623.180,  1203.230,  110.916 },
    { "Redsands West",              1236.630,  1883.110,  -89.084,  1777.390,  2142.860,  110.916 },
    { "Santa Maria Beach",          342.648,   -2173.290, -89.084,  647.712,   -1684.650, 110.916 },
    { "Verdant Bluffs",             1249.620,  -2179.250, -89.084,  1692.620,  -1842.270, 110.916 },
    { "Las Venturas Airport",       1236.630,  1203.280,  -89.084,  1457.370,  1883.110,  110.916 },
    { "Flint Range",                -594.191,  -1648.550, 0.000,    -187.700,  -1276.600, 200.000 },
    { "Verdant Bluffs",             930.221,   -2488.420, -89.084,  1249.620,  -2006.780, 110.916 },
    { "Palomino Creek",             2160.220,  -149.004,  0.000,    2576.920,  228.322,   200.000 },
    { "Ocean Docks",                2373.770,  -2697.090, -89.084,  2809.220,  -2330.460, 110.916 },
    { "Easter Bay Airport",         -1213.910, -50.096,   -4.5,     -947.980,  578.396,   200.000 },
    { "Whitewood Estates",          883.308,   1726.220,  -89.084,  1098.310,  2507.230,  110.916 },
    { "Calton Heights",             -2274.170, 744.170,   -6.1,     -1982.320, 1358.900,  200.000 },
    { "Easter Basin",               -1794.920, 249.904,   -9.1,     -1242.980, 578.396,   200.000 },
    { "Los Santos Inlet",           -321.744,  -2224.430, -89.084,  44.615,    -1724.430, 110.916 },
    { "Doherty",                    -2173.040, -222.589,  -1.0,     -1794.920, 265.243,   200.000 },
    { "Mount Chiliad",              -2178.690, -2189.910, -47.917,  -2030.120, -1771.660, 576.083 },
    { "Fort Carson",                -376.233,  826.326,   -3.0,     123.717,   1220.440,  200.000 },
    { "Foster Valley",              -2178.690, -1115.580, 0.000,    -1794.920, -599.884,  200.000 },
    { "Ocean Flats",                -2994.490, -222.589,  -1.0,     -2593.440, 277.411,   200.000 },
    { "Fern Ridge",                 508.189,   -139.259,  0.000,    1306.660,  119.526,   200.000 },
    { "Bayside",                    -2741.070, 2175.150,  0.000,    -2353.170, 2722.790,  200.000 },
    { "Las Venturas Airport",       1457.370,  1203.280,  -89.084,  1777.390,  1883.110,  110.916 },
    { "Blueberry Acres",            -319.676,  -220.137,  0.000,    104.534,   293.324,   200.000 },
    { "Palisades",                  -2994.490, 458.411,   -6.1,     -2741.070, 1339.610,  200.000 },
    { "North Rock",                 2285.370,  -768.027,  0.000,    2770.590,  -269.740,  200.000 },
    { "Hunter Quarry",              337.244,   710.840,   -115.239, 860.554,   1031.710,  203.761 },
    { "Los Santos International",   1382.730,  -2730.880, -89.084,  2201.820,  -2394.330, 110.916 },
    { "Missionary Hill",            -2994.490, -811.276,  0.000,    -2178.690, -430.276,  200.000 },
    { "San Fierro Bay",             -2616.400, 1659.680,  -3.0,     -1996.660, 2175.150,  200.000 },
    { "Restricted Area",            -91.586,   1655.050,  -50.000,  421.234,   2123.010,  250.000 },
    { "Mount Chiliad",              -2997.470, -1115.580, -47.917,  -2178.690, -971.913,  576.083 },
    { "Mount Chiliad",              -2178.690, -1771.660, -47.917,  -1936.120, -1250.970, 576.083 },
    { "Easter Bay Airport",         -1794.920, -730.118,  -3.0,     -1213.910, -50.096,   200.000 },
    { "The Panopticon",             -947.980,  -304.320,  -1.1,     -319.676,  327.071,   200.000 },
    { "Shady Creeks",               -1820.640, -2643.680, -8.0,     -1226.780, -1771.660, 200.000 },
    { "Back o Beyond",              -1166.970, -2641.190, 0.000,    -321.744,  -1856.030, 200.000 },
    { "Mount Chiliad",              -2994.490, -2189.910, -47.917,  -2178.690, -1115.580, 576.083 },
    { "Tierra Robada",              -1213.910, 596.349,   -242.990, -480.539,  1659.680,  900.000 },
    { "Flint County",               -1213.910, -2892.970, -242.990, 44.615,    -768.027,  900.000 },
    { "Whetstone",                  -2997.470, -2892.970, -242.990, -1213.910, -1115.580, 900.000 },
    { "Bone County",                -480.539,  596.349,   -242.990, 869.461,   2993.870,  900.000 },
    { "Tierra Robada",              -2997.470, 1659.680,  -242.990, -480.539,  2993.870,  900.000 },
    { "San Fierro",                 -2997.470, -1115.580, -242.990, -1213.910, 1659.680,  900.000 },
    { "Las Venturas",               869.461,   596.349,   -242.990, 2997.060,  2993.870,  900.000 },
    { "Red County",                 -1213.910, -768.027,  -242.990, 2997.060,  596.349,   900.000 },
    { "Los Santos",                 44.615,    -2892.970, -242.990, 2997.060,  -768.027,  900.000 }
}

local ZoneManager = {}

function ZoneManager:get_zone(x, y)
    for _, zone in ipairs(ZONES) do
        if x >= zone[2] and y >= zone[3] and x <= zone[5] and y <= zone[6] then
            return zone[1]
        end
    end
    return "Unknown"
end

function ZoneManager:get_current_zone()
    if getActiveInterior() ~= 0 then
        return "Interior"
    end

    local px, py, pz = getCharCoordinates(PLAYER_PED)
    return self:get_zone(px, py)
end

return ZoneManager

end

return require('src.main')
