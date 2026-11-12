-- One /stats read on the first manual enable, then use MOTDs and current-session radio confirmations.
local R=require('src.core.Rules')
local shared=require('src.shared')
local F={}
local cfg,save
local s
local LOGIN_SCANS={{delay=3000,rows=15},{delay=6000,rows=20}}
local function reset_session()
    local first_read_pending=s and s.first_read_pending
    -- The saved frequency describes the previous session. Login may restore
    -- a different frequency, so wait for this session's server messages.
    s={enabled=cfg.auto_freq[0],first_read_pending=first_read_pending,
       next_motd=os.clock()+300,motd_until=0,stats_until=0,stats_capture_until=0}
end
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
local function observe_motd(freq,now)
    s.login_attempt=nil
    s.desired=freq;s.desired_at=now;s.need_apply=true
    if cfg.auto_freq[0] then s.next_motd=now+300 end
end

local function read_chat_rows(limit)
    local rows={}
    -- SA-MP stores the newest line at index 99, including when chat is sparse.
    for row=99,100-limit,-1 do
        local ok,text,prefix=pcall(sampGetChatString,row)
        if not ok then return end
        rows[#rows+1]={text=text or '',prefix=prefix or ''}
    end
    return rows
end

local function same_row(a,b)
    return a.text==b.text and a.prefix==b.prefix
end

local function find_login_motd(before,rows)
    -- Match the newest pre-login rows to the older end of this scan.
    -- The first overlap found is the longest and excludes the most old rows.
    local new_count
    for offset=0,#rows-1 do
        local i=1
        while offset+i<=#rows and same_row(before[i],rows[offset+i]) do i=i+1 end
        if offset+i>#rows then new_count=offset;break end
    end

    for i=1,new_count or #rows do
        local row=rows[i]
        local freq=row.prefix=='' and R.frequency(row.text)
        if freq then
            if new_count then return freq end
            -- Chat may have moved by more than the entire scan, or an old
            -- line may have changed. Reject a candidate also in the snapshot.
            local old=false
            for _,prior in ipairs(before) do
                if prior.prefix=='' and R.frequency(prior.text)==freq then old=true;break end
            end
            if not old then return freq end
        end
    end
end

local function start_login_scan(id)
    local before=read_chat_rows(LOGIN_SCANS[#LOGIN_SCANS].rows)
    if not before then return end
    local attempt={}
    s.login_attempt=attempt
    lua_thread.create(function()
        -- Both Enter and clicking Login send the dialog's affirmative response.
        while s.login_attempt==attempt and sampIsDialogActive() and sampGetCurrentDialogId()==id do
            wait(0)
        end
        for _,scan in ipairs(LOGIN_SCANS) do
            if s.login_attempt~=attempt or not cfg.auto_freq[0] then return end
            wait(scan.delay)
            if s.login_attempt~=attempt or not cfg.auto_freq[0] then return end
            local rows=read_chat_rows(scan.rows)
            if not rows then break end
            local freq=find_login_motd(before,rows)
            if freq then observe_motd(freq,os.clock());return end
        end
        if s.login_attempt==attempt then s.login_attempt=nil end
    end)
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
            s.login_attempt=nil
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
    reset_session()
    self.initialized=false
    shared.event_handler:register('SERVER_CONNECTED',function()return true end,reset_session)
    shared.event_handler:register('SHOW_DIALOG',function(id,style,title,button)
        return (style==2 or style==3) and R.trim(R.strip(title)):lower()=='login' and R.trim(R.strip(button)):lower()=='login'
    end,function(id)
        s.login_dialog=id
        s.login_attempt=nil
    end)
    shared.event_handler:register('SEND_DIALOG_RESPONSE',function(id,button)
        if id==s.login_dialog then return {id,button} end
    end,function(id,button)
        s.login_dialog=nil
        if button==1 and cfg.auto_freq[0] and sampGetChatString then start_login_scan(id) end
    end)
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
            observe_motd(freq,now)
            if cfg.auto_freq[0]then
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
