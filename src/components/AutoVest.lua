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
local OFFER_REPLY_SECONDS=3

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
    next_offer_at = 0,
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

local function _find_closest_valid_player(attempt)

    if _aim_is_held() then
        return nil
    end

    local local_pos_x, local_pos_y, local_pos_z = getCharCoordinates(PLAYER_PED)
    local max_dist = 6
    local closest, retry = nil, nil
    local connected,local_id=sampGetPlayerIdByCharHandle(PLAYER_PED)

    local function is_valid_player(player, id)
        if (connected and id==local_id) or player==PLAYER_PED or not doesCharExist(player) then return false end

        local skin=getCharModel(player)
        local match=_config.vester_mode[0]==VESTER_MODE.AUTOMATIC and Updates.is_alliance(skin)
        if _config.vester_mode[0]==VESTER_MODE.MANUAL then
            for _,group in ipairs(_config.groups) do
                for _,v in ipairs(group.skins) do if v==skin then match=true end end
            end
        end
        if not match then return false end

        local health=sampGetPlayerHealth(id)
        if health<=0 then return false end

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
            health = health,
            ped = player
        }
    end

    for id = 0, sampGetMaxPlayerId(true) do
        if sampIsPlayerConnected(id) then
            local ok, ped = sampGetCharHandleBySampPlayerId(id)

            if ok then
                local player_data = is_valid_player(ped, id)

                if player_data then
                    if attempt and id==attempt.id and sampGetPlayerNickname(id)==attempt.name then
                        retry=player_data
                    elseif not closest then
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

    return closest or retry
end

local function _handle_ped_tick()
    local state=_auto_vest_state
    local now=os.clock()
    local attempt=state.attempt
    if now<state.next_offer_at or (attempt and now<attempt.reply_by) then return end

    -- Only consider alternatives once the previous attempt's reply window
    -- has expired. The original still has to pass the current selection filters.
    local target = _find_closest_valid_player(attempt)
    if not target then
        return
    end

    _get_active_timer():set_temp_interval(OFFER_REPLY_SECONDS)

    local cmd_mode = _config.command_mode.current[0]
    local command = cmd_mode == COMMAND_MODE.NORMAL and "guard" or "guardnear"

    state.attempt={id=target.player_id,name=sampGetPlayerNickname(target.player_id),mode=cmd_mode,reply_by=now+OFFER_REPLY_SECONDS}
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
        function(_, text)
            return Rules.trim(Rules.strip(text)) == "You are not a bodyguard."
        end,
        function()
            _auto_vest_state.timers[COMMAND_MODE.NORMAL]:pause()
            local attempt=_auto_vest_state.attempt
            if attempt and attempt.mode==COMMAND_MODE.NORMAL then _auto_vest_state.attempt=nil end
            local now=os.clock()
            if not _auto_vest_state.last_job_warning or now-_auto_vest_state.last_job_warning>=5 then
                _auto_vest_state.last_job_warning=now
                -- Group the final highlights to keep the entire message within SA-MP's 144-byte limit.
                sampAddChatMessage('[Leone Menu] {FFFFFF}You dont have {33CCFF}bodyguard job{FFFFFF}, switch to {33CCFF}DD mode in /leone or get to Ganton Gym and change job',0xFF1E3348)
            end
        end
    )

    shared.event_handler:register(
        "SERVER_MESSAGE",
        function(_, text)
            local name=Rules.trim(Rules.strip(text)):match('^%* You offered protection to (.-) for %$%d[%d,]*%.$')
            return name and {name}
        end,
        function(player_name)
            local state=_auto_vest_state
            local attempt=state.attempt
            local raw_name=player_name:gsub(' ','_')
            local timer=_get_active_timer()
            if attempt and attempt.name:lower()==raw_name:lower() then
                timer=state.timers[attempt.mode]
                state.attempt=nil
            end
            _auto_vest_state.last_vest_recipient_name = player_name
            _auto_vest_state.pending={name=player_name,id=Player:get_player_id_by_name(raw_name),price=200}
            timer:trigger()
            local until_time=os.clock()+timer:get_active_interval()
            state.cooldown_until=until_time
            state.next_offer_at=math.max(state.next_offer_at,until_time)
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
            _auto_vest_state.attempt=nil
            _get_active_timer():set_temp_interval(seconds)
            _auto_vest_state.cooldown_until=math.max(_auto_vest_state.cooldown_until,os.clock()+seconds)
            _auto_vest_state.next_offer_at=math.max(_auto_vest_state.next_offer_at,os.clock()+seconds)
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
