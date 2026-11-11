local bit=require('bit')
local fa=require('fAwesome7')
local imgui=require('upmimgui')
local Colors=require('src.core.Colors')
local Config=require('src.core.Config')
local H=require('src.ui.Helpers')
local MainWindow=require('src.ui.MainWindow')
local Overlay=require('src.ui.Overlay')
local Player=require('src.utils.Player')
local Realign=require('src.utils.ElementRealigner')
local Rules=require('src.core.Rules')
local shared=require('src.shared')

local Lawyer={}
local path='config/Leone Menu/lawyer.json'
local cfg={cooldown=imgui.new.int(70),defend={keys={}},free={keys={}},overlay=Overlay.setup_overlay_defaults(
    true,0.015,0.64,14,6,1,2,true,{0,0,0,0.588},true,{0,0,0,0.588})}
local labels={defend='Auto Lawyer',free='Auto Free'}
local commands={defend='al',free='afree'}
local last_targets,active={},{}
local pending,wanted,last_mode
local wanted_cache,next_wanted_at,manual_wanted_until=nil,0,0
local WANTED_REPLY_SECONDS=4
local cooldown_until=0
local attempted_until=0

local function plain_name(name) return Rules.trim(name):gsub('_',' ') end
local function notify(text) sampAddChatMessage('[Leone Mods] {FFFFFF}'..text,0xFF1E3348) end
local function seconds_text(seconds) return ('{00FF00}%ds{FFFFFF}'):format(seconds) end
local function target_text(target)
    return ('{%06X}%s{FFFFFF} (%d)'):format(target.color,plain_name(target.name),target.id)
end
local function snapshot(id)
    return {id=id,name=sampGetPlayerNickname(id),color=bit.band(sampGetPlayerColor(id) or -1,0xFFFFFF)}
end
local function cooldown() return math.max(60,cfg.cooldown[0]) end
local function remaining() return math.max(0,math.ceil(cooldown_until-os.clock())) end
local function playable()
    return sampGetGamestate()==3 and sampIsLocalPlayerSpawned() and not sampIsChatInputActive()
        and not sampIsDialogActive() and not isPauseMenuActive() and not MainWindow:is_open()
end

local function disable(mode)
    active[mode]=nil
    notify(labels[mode]..' has been {FF0000}disabled{FFFFFF}')
end

local function toggle(mode,args)
    args=Rules.trim(args or '')
    local id=tonumber(args)
    local current=active[mode]
    if current and (args=='' or current.id==id) then return disable(mode) end
    local previous=last_targets[mode]
    if args=='' and previous and sampIsPlayerConnected(previous.id) and sampGetPlayerNickname(previous.id)==previous.name then id=previous.id end
    if not id or id%1~=0 or id<0 or id>sampGetMaxPlayerId(false) or not sampIsPlayerConnected(id) then
        notify('Usage /'..commands[mode]..' [connected player ID]');return
    end
    local ok,my_id=sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok and id==my_id then return end
    local target=snapshot(id)
    active[mode]=target;last_targets[mode]=target
    notify(labels[mode]..' has been {00FF00}enabled{FFFFFF} on '..target_text(target)..' with '..seconds_text(cooldown())..' cooldown')
end

local function send(mode,target,hotkey)
    local seconds=cooldown()
    cooldown_until=os.clock()+seconds
    attempted_until=os.clock()+10
    last_mode=mode
    pending=hotkey and {mode=mode,target=target,seconds=seconds,expires=os.clock()+10} or nil
    sampSendChat(('/%s %d%s'):format(mode,target.id,mode=='defend' and ' 200' or ''))
end

local function nearby(filter,range)
    return Player:get_closest_player_id(range or 7,{function(id,ped)
        return ped~=PLAYER_PED and doesCharExist(ped) and sampIsPlayerConnected(id) and filter(id,ped)
    end})
end

local function try_target(mode)
    local target=active[mode]
    if not target then return false end
    if not sampIsPlayerConnected(target.id) or sampGetPlayerNickname(target.id)~=target.name then
        disable(mode);return false
    end
    if not nearby(function(id) return id==target.id end) then return false end
    send(mode,target,false)
    return true
end

local function choose_nearby(mode,suspects)
    local found,id=nearby(function(id,ped)
        if mode=='free' then return getCharModel(ped)==50 end
        return suspects[id]==plain_name(sampGetPlayerNickname(id)):lower()
    end,mode=='free' and Player.VEST_RANGE or nil)
    if found then send(mode,snapshot(id),true)
    else notify(mode=='free' and 'No nearby prisoner found.' or 'No nearby wanted player found.') end
end

local function nearest(mode)
    if remaining()>0 then notify('Lawyer CD: '..seconds_text(remaining()));return end
    local now=os.clock()
    if wanted and now<=wanted.expires then return end
    if mode=='free' then choose_nearby(mode);return end
    if now<manual_wanted_until then return end
    if now<next_wanted_at then
        if wanted_cache then choose_nearby(mode,wanted_cache) end
        return
    end
    wanted_cache=nil
    next_wanted_at=now+cooldown()
    wanted={expires=now+WANTED_REPLY_SECONDS}
    samp_send_hidden_command('wanted')
end

local function handle_wanted_reply(color,text)
    if not wanted or os.clock()>wanted.expires then return end
    if color==Colors.ORANGE and text=='__________WANTED LIST__________' then
        wanted.suspects={}
        return false
    end
    if color==Colors.WHITE then
        local name,id=text:match('^(.-) %((%d+)%)%:%s*%d+ outstanding charges?%.$')
        if id and wanted.suspects then
            wanted.suspects[tonumber(id)]=plain_name(name):lower()
            return false
        end
    end
    if color==Colors.WHITE and text=='No current wanted suspects.' then
        wanted_cache={}
    elseif color==Colors.ORANGE and text=='________________________________' and wanted.suspects then
        wanted_cache=wanted.suspects
    else
        return
    end
    wanted=nil
    if remaining()==0 and playable() then choose_nearby('defend',wanted_cache) end
    return false
end

local function handle_chat(color,text)
    local wait_seconds=text:match('^You must wait (%d+) seconds? before you can defend again!$')
    if wait_seconds and os.clock()<attempted_until then
        cooldown_until=math.max(cooldown_until,os.clock()+tonumber(wait_seconds)+1)
    end
    if (text=='You are not a Lawyer!' and (next(active) or wanted or os.clock()<attempted_until))
        or (wanted and os.clock()<=wanted.expires and text=="You're not a Lawyer / Cop / FBI!") then
        active={}
        pending,wanted=nil,nil
        wanted_cache=nil
        attempted_until,cooldown_until=0,0
        msg("You're not a {00FF00}lawyer{FFFFFF}, go get the job at {00FF00}Downtown Los Santos")
        return false
    end
    if handle_wanted_reply(color,text)==false then return false end
    if not pending or os.clock()>pending.expires then return end
    local name
    if pending.mode=='defend' then
        name=text:match('^%* You offered to defend (.-) for %$%d[%d,]*%.$')
    else
        name=text:match('^%*?%s*You have reduced (.-)\'s sentence by ')
            or text:match('^%*?%s*You have reduced (.-)\'s jail time by ')
            or text:match('^%*?%s*You reduced (.-)\'s sentence by ')
            or text:match('^%*?%s*You have freed (.-) from jail%.$')
    end
    if name and plain_name(name):lower()==plain_name(pending.target.name):lower() then
        local result=pending.mode=='defend' and ' has been lawyered' or ' had their time reduced'
        notify(labels[pending.mode]..', '..target_text(pending.target)..result..', with '..seconds_text(pending.seconds)..' cooldown')
        pending=nil
    end
end

function Lawyer:register()
    Config.load(path,cfg)
    if cfg.cooldown[0]==66 then cfg.cooldown[0]=70 end
    cfg.cooldown[0]=cooldown()
    for _,mode in ipairs({'defend','free'}) do
        local command=commands[mode]
        local bound=mode
        if sampIsChatCommandDefined and sampIsChatCommandDefined(command) then
            notify('/'..command..' is already registered. Leone Lawyer uses /leone'..command..' for this session.')
            command='leone'..command
        end
        sampRegisterChatCommand(command,function(args) toggle(bound,args) end)
        shared.hotkey_manager:register('lawyer_'..bound,cfg[bound].keys,function() nearest(bound) end)
    end
    shared.event_handler:register('SERVER_MESSAGE',function(color,text)
        return (wanted or pending or next(active) or os.clock()<attempted_until) and {color,Rules.trim(Rules.strip(text))}
    end,handle_chat)
    shared.event_handler:register('SEND_COMMAND',function(command)
        local name=command:match('^/(%S+)')
        return name and (name:lower()=='defend' or name:lower()=='free')
    end,function() attempted_until=os.clock()+10 end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        return Rules.trim(command):lower()=='/wanted' and is_command_self_sent('wanted')
    end,function()
        -- The server provides no request ID. Give manual output priority when requests overlap.
        wanted=nil
        manual_wanted_until=os.clock()+WANTED_REPLY_SECONDS
    end)
    shared.event_handler:register('PED_TICK',function() return next(active)~=nil or wanted~=nil or pending~=nil end,function()
        local now=os.clock()
        if wanted and now>wanted.expires then wanted=nil;notify('Could not read the HZG wanted list.') end
        if pending and now>pending.expires then pending=nil end
        if remaining()>0 or wanted or not playable() then return end
        local first=last_mode=='defend' and 'free' or 'defend'
        if not try_target(first) then try_target(first=='defend' and 'free' or 'defend') end
    end)

    local function overlay_seconds()
        local seconds=remaining()
        return seconds==0 and Realign:is_preview('lawyer') and 3 or seconds
    end
    local overlay=Overlay.new(cfg.overlay,function()
        return Realign:is_preview('lawyer') or (cfg.overlay.display[0] and remaining()>0)
    end,function(self)
        local seconds=overlay_seconds()
        if seconds>0 then self:TextRGB(('{FFFFFF}%s Lawyer CD: {28DC40}%ds'):format(fa('CLOCK'),seconds)) end
    end)
    overlay.allowed_colors={['28DC40']=true}
end

function Lawyer:save_config() return Config.save(path,cfg) end
function Lawyer:get_overlay_config()return cfg.overlay end

function Lawyer:render()
    imgui.DrawChild('Lawyering',function(width)
        imgui.Text('Auto Lawyer - /al ID (type /al or same ID again to stop/start)')
        H.bind('Auto Lawyer nearest wanted','lawyer_defend',cfg.defend,width)
        imgui.Separator()
        imgui.Text('Auto Free - /afree ID (type /afree or same ID again to stop/start)')
        H.bind('Auto Free nearest prisoner','lawyer_free',cfg.free,width)
        imgui.Separator()
        imgui.Text('Cooldown on /afree and /al');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##lawyer_cooldown',cfg.cooldown)
        cfg.cooldown[0]=cooldown()
        imgui.TextDisabled('The minimum cooldown is 1 minute. Add a few seconds to allow for lag or delay.')
        imgui.Separator()
        H.position_text(width,imgui.ToggleButtonWidth()+104+H.reset_size_width+2*imgui.GetStyle().ItemSpacing.x)
        H.reset_size_button({cfg.overlay},'lawyer')
        imgui.SameLine()
        if imgui.AnimButton('Position##lawyer',imgui.ImVec2(104,0)) then
            H.realign({cfg.overlay},'lawyer')
        end
        H.position_tip()
        imgui.SameLine();imgui.ToggleButton('##lawyer_overlay',cfg.overlay.display)
    end)
end

return Lawyer
