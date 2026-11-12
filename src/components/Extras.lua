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
local ChatDedup=require('src.components.ChatDedup')
local E={}
local cfg={frisk={keys={}},repair={keys={}},skip=imgui.new.bool(true),anti_spam=imgui.new.bool(false),auto_freq=imgui.new.bool(false),last_frequency=0}
local file='config/Leone Menu/misc-extras.json'
local STARTUP_NOTICE_SECONDS=8
local state={para_until=0,last_notice=-10,notice_ready=false}
function E:register()
    Config.load(file,cfg)
    ChatDedup.configure(cfg.anti_spam)
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
    sampRegisterChatCommand('ins',function(args)
        local n=tonumber(args)
        if not n or n%1~=0 or n<1 or n>6 then
            msg('/ins [1-6]')
            sampAddChatMessage('1: All Saints Hospital - 2: County General Hospital - 3: Blueberry Clinic - 4: Maximus Club - 5: First House - 6: Second House',0xFFFFFFFF)
            return
        end
        sampSendChat('/insurance '..n)
    end)
    sampRegisterChatCommand('v',function() sampSendChat('/guardnear') end)
    local para=Overlay.setup_overlay_defaults(true,0.015,0.43,14,8,1,2,true,{0,0,0,0.75},true,{30/255,51/255,72/255,1})
    local loaded=Overlay.setup_overlay_defaults(true,0.015,0.50,17,10,1,6,true,{0.035,0.045,0.06,0.96},true,{30/255,51/255,72/255,1})
    Overlay.new(para,function() return os.clock()<state.para_until end,function(self) self:TextRGB('{FFFFFF}Parachute\navailable') end)
    Overlay.new(loaded,function()
        return state.notice_ready and (not state.loaded_until or os.clock()<state.loaded_until)
    end,function(self)
        state.loaded_until=state.loaded_until or os.clock()+STARTUP_NOTICE_SECONDS
        self:TextRGB('{FFFFFF}Leone Menu')
        imgui.PushFont(nil,13)
        imgui.Text('Version '..require('src.core.Updates').version)
        imgui.PopFont()
    end)
    addEventHandler('onScriptTerminate',function(scr)
        if scr==script.this then self:stop_startup_audio() end
    end)
end
local function startup_ready()
    return doesCharExist(PLAYER_PED) and sampIsLocalPlayerSpawned() and sampGetGamestate()==3
        and not sampIsDialogActive() and not isPauseMenuActive()
end
function E:can_update()
    return state.loaded_until~=nil and os.clock()>=state.loaded_until and startup_ready() and not sampIsChatInputActive()
end
function E:stop_startup_audio()
    local stream=state.audio
    state.audio=nil
    if stream then releaseAudioStream(stream) end
end
function E:loaded(on_ready)
    lua_thread.create(function()
        while not startup_ready() do wait(100) end
        wait(1000)
        while not startup_ready() do wait(100) end
        local ok,err=pcall(require('src.components.Fixes').preload_animations)
        if not ok then print('[Leone Menu] Animation preload failed: '..tostring(err)) end
        Frequency:loaded()
        state.notice_ready=true
        if on_ready then on_ready() end
        local ok,stream=pcall(loadAudioStream,getWorkingDirectory()..'/resource/Leone Menu/modloadedin.mp3')
        if ok and stream and stream~=0 then
            state.audio=stream
            setAudioStreamState(stream,1)
            wait(15000)
            self:stop_startup_audio()
        end
    end)
end
function E:get_config() return cfg end
function E:save_config() return Config.save(file,cfg) end
function E:render_frisk(width) H.bind('Aim and frisk a player','aim_frisk',cfg.frisk,width) end
function E:render_repair(width) H.bind('Offer $1 repair to nearest driver or passenger','repair_nearest',cfg.repair,width) end
function E:render_radio(width) H.toggle('Checks /fmotd for alliance frequency and changes freq','auto_freq',cfg.auto_freq,width,'Listens for /fmotd in chat to read the freq and auto swaps to the newest one, it does an automatic silent check every 5 minutes also') end
function E:render_random()
    imgui.DrawChild('Random',function(width)
        imgui.Text('Parachute')
        H.toggle('Skips over parachute but it reappears once you\'re falling - /skippara','skip_para',cfg.skip,width,"Skips over the parachute to the next available weapon or fist, displays a small overlay to notify you that you got a parachute. the parachute appears again when you're falling")
        imgui.Separator()
        if H.toggle('Anti Spam','anti_spam',cfg.anti_spam,width,
            'Prevent repeated messages by showing the count at the end of the chat.\ne.g. [x2] would mean the same chat was repeated 2 times in a row.') then
            ChatDedup.configure(cfg.anti_spam)
            self:save_config()
        end
        imgui.Separator()
        imgui.Text('Shortcuts');imgui.Text('Sign check - /si')
        imgui.Text('Change insurance location - /ins')
        imgui.Text('Guard nearby players quickly (guardnear) - /v')
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
