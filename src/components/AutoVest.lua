-- Module: F:\2025\EDrive\dev\luapack\src\components\AutoVest.lua

local carboneum = require("src.core.Config")
local fa = require("fAwesome7")
local imgui = require("upmimgui")
local keys = require("game.keys")

local Updates = require("src.core.Updates")
local skin_feed = require('src.components.VestSkinFeed').new()
local H = require("src.ui.Helpers")
local Rules = require("src.core.Rules")
local Editor = require("src.ui.AllianceEditor")
local Colors = require("src.core.Colors")
local MainWindow = require("src.ui.MainWindow")
local Overlay = require("src.ui.Overlay")
local Player = require("src.utils.Player")
local shared = require("src.shared")
local Timer = require("src.core.Timer")
local VestRules=require('src.core.VestRules')

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
            [COMMAND_MODE.DD] = imgui.new.int(7),
        },
    },
    vester_mode = imgui.new.int(VESTER_MODE.AUTOMATIC),
    skin_url = '',
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
    if not VestRules.can_offer(true) or sampGetGamestate()~=3 or is_cursor_active()
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
    if not is_within_distance_3d(x,y,z,tx,ty,tz,Player.VEST_RANGE)then return end
    _get_active_timer():set_temp_interval(3)
    sampSendChat(string.format('/guard %d 200',request.id))
end

local function _find_closest_valid_player(attempt)

    if _aim_is_held() then
        return nil
    end

    local local_pos_x, local_pos_y, local_pos_z = getCharCoordinates(PLAYER_PED)
    local max_dist = Player.VEST_RANGE
    local closest, retry = nil, nil
    local connected,local_id=sampGetPlayerIdByCharHandle(PLAYER_PED)

    local function is_valid_player(player, id)
        if (connected and id==local_id) or player==PLAYER_PED or not doesCharExist(player)
            or sampIsPlayerPaused(id) or isCharPlayingAnim(player,'KILL_Knife_Ped_Die') then return false end

        local skin=getCharModel(player)
        local match=_config.vester_mode[0]==VESTER_MODE.AUTOMATIC and Updates.is_alliance(skin)
        if _config.vester_mode[0]==VESTER_MODE.MANUAL then
            for _,group in ipairs(_config.groups) do
                for _,v in ipairs(group.skins) do if v==skin then match=true end end
            end
        end
        if not match and not skin_feed.skins[skin] then return false end

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
    if not VestRules.can_offer(false) then state.attempt=nil;return end
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

    local function swap_mode()
        local mode=_config.command_mode.current[0]==COMMAND_MODE.DD and COMMAND_MODE.NORMAL or COMMAND_MODE.DD
        _config.command_mode.current[0]=mode
        local name,command=mode==COMMAND_MODE.DD and 'DD' or 'Normal',mode==COMMAND_MODE.DD and '/guardnear' or '/guard'
        msg(('Auto Vest Mode has changed to {00FF00}%s{FFFFFF} (%s) %ds delay'):format(name,command,_config.command_mode.intervals[mode][0]))
    end
    sampRegisterChatCommand('avmode',swap_mode)
    sampRegisterChatCommand('ddmode',swap_mode)
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
    skin_feed:set_url(_config.skin_url)
    if _config.command_mode.intervals[COMMAND_MODE.DD][0]==10 then _config.command_mode.intervals[COMMAND_MODE.DD][0]=7 end
    VestRules.register()

    _register_event_handlers()
    _register_commands()
    shared.event_handler:register('HOSPITAL_ADMITTED',function()return true end,function()
        _auto_vest_state.pending=nil;_auto_vest_state.attempt=nil;_auto_vest_state.aim_request=nil
        _auto_vest_state.cooldown_until=0
    end)
    shared.hotkey_manager:register('aim_vest',_config.aim.keys,function()
        local ok,ped=getCharPlayerIsTargeting(PLAYER_HANDLE)
        if not ok or not doesCharExist(ped) then return end
        local connected,id=sampGetPlayerIdByCharHandle(ped)
        if connected then _auto_vest_state.aim_request={id=id,name=sampGetPlayerNickname(id)} end
    end)
    shared.event_handler:register('PED_TICK',function()return _auto_vest_state.aim_request~=nil end,_process_aim_request)
    shared.event_handler:register('PED_TICK',function()return skin_feed.url~='' or skin_feed.request or _ui_state.save_url_at end,function()
        skin_feed:tick()
        if _ui_state.save_url_at and os.clock()>=_ui_state.save_url_at then
            _ui_state.save_url_at=nil
            if not self:save_config() then _ui_state.save_url_at=os.clock()+5 end
        end
    end)
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
    return carboneum.save(CONFIG_PATH, _config)
end

function AutoVest:render_ui_settings()
    imgui.DrawChild('Auto Vest',function(width)
        H.toggle('Automatically vest nearby players - /avest','auto_vest',_config.is_enabled,width)
        imgui.Separator()
        H.bind('Aim and vest','aim_vest',_config.aim,width)
        imgui.Separator()
        imgui.Text('Command mode - /avmode to swap between Normal and DD')
        imgui.SameLine(width-250)
        imgui.SegmentedControl('command_mode',{'Normal','DD'},_config.command_mode.current,imgui.ImVec2(250,0))
        imgui.Separator()
        local url_width=60
        local mode_right=width-url_width-imgui.GetStyle().ItemSpacing.x
        imgui.Text('Alliance skins to be vested');imgui.SameLine(mode_right-290)
        if imgui.AnimButton(fa('GEAR')) then
            Editor:show(_config.groups,function(groups)
                local previous=_config.groups
                _config.groups=groups
                if self:save_config() then return true end
                _config.groups=previous
                return false
            end)
        end
        imgui.SameLine(mode_right-250)
        imgui.SegmentedControl('alliance_mode',{'Automatic','Manual'},_config.vester_mode,imgui.ImVec2(250,0))
        if imgui.IsItemHovered() then imgui.SetTooltip('Automatic grabs Leone alliance skins; it can be outdated for 1-2 days. Use Manual in the meantime. Manual uses the groups added in the cogwheel.') end
        imgui.SameLine(width-url_width)
        if imgui.AnimButton('URL',imgui.ImVec2(url_width,0)) then _ui_state.skin_url_open=not _ui_state.skin_url_open end
        if imgui.IsItemHovered() then imgui.SetTooltip('Add a URL to an HTML skin list. Auto Vest will also vest players with those skin IDs.') end
        if _ui_state.skin_url_open then
            local url,changed=H.input('##vest_skin_url',_config.skin_url,'HTML url here...',imgui.GetContentRegionAvail().x,2048)
            if changed then
                _config.skin_url=url
                skin_feed:set_url(url)
                _ui_state.save_url_at=os.clock()+0.5
            end
            if skin_feed.status then imgui.TextDisabled('%s',skin_feed.status) end
        end
        imgui.Separator()
        imgui.Text('Vest interval (seconds)');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##vest_interval',_config.command_mode.intervals[_config.command_mode.current[0]])
        local interval=_config.command_mode.intervals[_config.command_mode.current[0]];interval[0]=math.max(1,interval[0])
        imgui.Separator()
        imgui.Text('Offer if vest is below');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##offer_below',_config.offer_if_armor_below);_config.offer_if_armor_below[0]=math.max(0,math.min(100,_config.offer_if_armor_below[0]))
        imgui.Separator()
        H.toggle('Show offered-to overlay','offered_to',_config.overlay.display,width)
    end)
    require('src.components.AcceptVest'):render_ui_settings()
    H.position({_config.overlay,require('src.components.AcceptVest'):get_overlay_config()},'vesting')
    Editor:render()
end
return AutoVest
