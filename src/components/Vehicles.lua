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
