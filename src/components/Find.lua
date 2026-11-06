-- Sputnik's periodic find system, without the removed Wanted/Badge/MDC features.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local Config=require('src.core.Config')
local MainWindow=require('src.ui.MainWindow')
local Player=require('src.utils.Player')
local Rules=require('src.core.Rules')
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
local function stop(job_denied)
    state.enabled=false;state.next_lookup=nil;state.resume_at=nil
    if job_denied then
        sampAddChatMessage("[Leone Menu] {FFFFFF}Auto Find turned {FF0000}off{FFFFFF}, you're not a {00FF00}detective{FFFFFF}, go to {00FF00}LSPD HQ{FFFFFF} and get the job",0xFF1E3348)
    else
        msg('AutoFind: {FF0000}OFF')
    end
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
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)
        return state.enabled and Rules.trim(Rules.strip(text))=='You are not a detective.'
    end,function() stop(true);return false end)
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
function F:save_config() return Config.save('config/Leone Menu/autofind.json',cfg) end
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
