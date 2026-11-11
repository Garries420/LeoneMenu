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
function E:save_config() return Config.save(file,cfg) end
function E:render_ui_settings()
    imgui.DrawChild('Blackmarket',function(width)
        imgui.Text('Select mode: /bms or /bms [Mode Number]')
        imgui.Separator()
        H.toggle('Keybind enabled','bm_enabled',cfg.enabled,width)
        imgui.Separator()
        H.bind('Keybind','blackmarket',cfg,width)
        imgui.Separator();imgui.Text('Keybind Modes:')
        for i,name in ipairs(names) do
            if cfg.mode[0]==i then imgui.TextColored(imgui.ImVec4(0,1,0,1),i..'. '..name) else imgui.Text(i..'. '..name) end
        end
        imgui.Separator();imgui.Text('Current Mode');imgui.SameLine(width-160);imgui.SetNextItemWidth(160);imgui.InputInt('##bm_mode',cfg.mode);cfg.mode[0]=math.max(1,math.min(4,cfg.mode[0]))
        imgui.Separator()
        imgui.Text('Purchase gap (ms)');imgui.SameLine(width-160);imgui.SetNextItemWidth(160);imgui.InputInt('##bm_delay',cfg.delay);cfg.delay[0]=math.max(MIN_PURCHASE_GAP,math.min(5000,cfg.delay[0]))
    end)
end
return E
