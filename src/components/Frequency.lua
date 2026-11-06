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
