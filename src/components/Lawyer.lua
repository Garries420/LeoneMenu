local bit=require('bit')
local fa=require('fAwesome7')
local imgui=require('upmimgui')
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
local cfg={cooldown=imgui.new.int(66),defend={keys={}},free={keys={}},overlay=Overlay.setup_overlay_defaults(
    true,0.015,0.64,14,6,1,2,true,{0,0,0,0.588},true,{0,0,0,0.588})}
local labels={defend='Auto Lawyer',free='Auto Free'}
local commands={defend='al',free='afree'}
local last_targets,active={},{}
local pending,wanted,last_mode
local cooldown_until=0

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
    last_mode=mode
    pending=hotkey and {mode=mode,target=target,seconds=seconds,expires=os.clock()+10} or nil
    sampSendChat(('/%s %d%s'):format(mode,target.id,mode=='defend' and ' 200' or ''))
end

local function nearby(filter)
    return Player:get_closest_player_id(7,{function(id,ped)
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
    end)
    if found then send(mode,snapshot(id),true)
    else notify(mode=='free' and 'No nearby prisoner found.' or 'No nearby wanted player found.') end
end

local function nearest(mode)
    if remaining()>0 then notify('Lawyer CD: '..seconds_text(remaining()));return end
    if wanted and os.clock()<wanted.expires then return end
    if mode=='free' then choose_nearby(mode);return end
    wanted={expires=os.clock()+4}
    sampSendChat('/wanted')
end

local function handle_chat(text)
    if wanted and os.clock()<=wanted.expires then
        if text=='__________WANTED LIST__________' then
            wanted.suspects={}
        elseif wanted.suspects then
            local name,id=text:match('^(.-) %((%d+)%)%:%s*%d+ outstanding charges?%.$')
            if id then wanted.suspects[tonumber(id)]=plain_name(name):lower() end
            if text=='________________________________' or text=='No current wanted suspects.' then
                local suspects=wanted.suspects
                wanted=nil
                if remaining()==0 and playable() then choose_nearby('defend',suspects) end
            end
        end
    end
    if not pending or os.clock()>pending.expires then return end
    local name
    if pending.mode=='defend' then
        name=text:match('^%* You offered to defend (.-) for %$200%.$')
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
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)
        return (wanted or pending) and {Rules.trim(Rules.strip(text))}
    end,handle_chat)
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

function Lawyer:save_config() Config.save(path,cfg) end

function Lawyer:render()
    imgui.DrawChild('Lawyering',function(width)
        imgui.Text('Auto Lawyer - /al ID (type /al or same ID again to stop/start)')
        H.bind('Auto Lawyer nearest wanted','lawyer_defend',cfg.defend,width)
        imgui.Text('Auto Free - /afree ID (type /afree or same ID again to stop/start)')
        H.bind('Auto Free nearest prisoner','lawyer_free',cfg.free,width)
        imgui.Text('Cooldown on /afree and /al');imgui.SameLine(width-120);imgui.SetNextItemWidth(120)
        imgui.InputInt('##lawyer_cooldown',cfg.cooldown)
        cfg.cooldown[0]=cooldown()
        imgui.Text('Overlay')
        imgui.SameLine(width-imgui.ToggleButtonWidth()-104-imgui.GetStyle().ItemSpacing.x)
        if imgui.AnimButton('Position##lawyer',imgui.ImVec2(104,0)) then
            Realign:realign_element(function(x,y) cfg.overlay.pos.x[0]=x;cfg.overlay.pos.y[0]=y end,{preview='lawyer'})
        end
        imgui.SameLine();imgui.ToggleButton('##lawyer_overlay',cfg.overlay.display)
        imgui.TextDisabled('The minimum cooldown is 1 minute. Add a few seconds to allow for lag or delay.')
    end)
end

return Lawyer
