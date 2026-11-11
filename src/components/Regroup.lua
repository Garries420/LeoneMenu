local imgui=require('upmimgui')
local R=require('src.core.Rules')
local Player=require('src.utils.Player')
local Find=require('src.components.Find')
local shared=require('src.shared')
local G={rows={},visible=false,open=false,requests={}}
local RADIUS=math.sqrt((2314.0879-2260.5500)^2+(-1143.3927+1235.4124)^2)
G.radius=RADIUS
local function name_key(name) return R.trim(R.strip(name)):lower():gsub('_',' ') end
local function same_player(row)
    return row.id and sampIsPlayerConnected(row.id) and name_key(sampGetPlayerNickname(row.id))==name_key(row.name)
end
local function collecting_here(snapshot)
    if not doesCharExist(PLAYER_PED) or not sampIsLocalPlayerSpawned() or getActiveInterior()~=snapshot.interior then return false end
    local x,y=getCharCoordinates(PLAYER_PED)
    return (x-snapshot.x)^2+(y-snapshot.y)^2<=25
end
local function can_mass_mention()
    return G.rank==5 or G.rank==6
end

function G:run()
    if self.collect then return end
    self.rows={};self.error=nil;self.pending=nil;self.mass=nil;self.rank=nil
    self.open=true;self.visible=true
    if not doesCharExist(PLAYER_PED) or not sampIsLocalPlayerSpawned() or sampGetGamestate()~=3 then
        self.error='Wait until you have spawned, then run /rgcheck again.';return
    end
    local x,y=getCharCoordinates(PLAYER_PED)
    local snapshot={x=x,y=y,interior=getActiveInterior(),nearby={},members={},started=os.clock()}
    for id=0,sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local streamed,ped=sampGetCharHandleBySampPlayerId(id)
            if streamed and doesCharExist(ped) then
                local px,py=getCharCoordinates(ped)
                if (px-x)^2+(py-y)^2<=RADIUS^2 then snapshot.nearby[name_key(sampGetPlayerNickname(id))]=true end
            end
        end
    end
    local me,id=sampGetPlayerIdByCharHandle(PLAYER_PED)
    if me then
        snapshot.local_name=name_key(sampGetPlayerNickname(id))
        snapshot.nearby[snapshot.local_name]=true
    end
    self.collect=snapshot
    samp_send_hidden_command('members')
end

local function finish_members()
    local snapshot=G.collect
    G.collect=nil
    if not collecting_here(snapshot) then G.error='You moved while checking. Run /rgcheck again.';return end
    if not snapshot.header or not snapshot.last then G.error='Could not read /members. Run /rgcheck again.';return end
    G.rank=snapshot.rank
    for key,row in pairs(snapshot.members) do
        if not snapshot.nearby[key] and not row.jailed then
            row.id=Player:get_player_id_by_name(row.name:gsub(' ','_'))
            if row.id then G.rows[#G.rows+1]=row end
        end
    end
    table.sort(G.rows,function(a,b)return name_key(a.name)<name_key(b.name)end)
end

function G:find(row)
    if Find:cooldown_remaining()>0 then return end
    -- A member can reconnect under a different ID while this list is open.
    local id=Player:get_player_id_by_name(row.name:gsub(' ','_'))
    if not id then row.location='Offline';row.result='failed';return end
    row.id=id
    if not Find:find_once(id) then return end
    row.location='Finding...';row.result='pending'
    local request={row=row,waiting=true}
    self.requests[name_key(row.name)]=request
    self.pending=request
end

local function complete(request,location,result)
    request.row.location=location;request.row.result=result
    request.waiting=false;request.quiet_until=os.clock()+60
    if G.pending==request then G.pending=nil end
end

local function find_result(text)
    local own=text:match('^SMS: I need the where%-abouts of (.-), Sender: ')
    if own and G.requests[name_key(own)] then return false end
    local name,where=text:match('^(.-) has been last seen at (.-)%.$')
    if not name then name,where=text:match('^SMS: Sources last seen (.-) go inside (.-), Sender: Unknown%.$') end
    local missing=text:match("^SMS: I can't find any liable sources for (.-), they're inside somewhere, Sender: Unknown%.$")
    local request=(name or missing) and G.requests[name_key(name or missing)]
    if request and request.waiting then
        complete(request,where or "Can't find",where and 'found' or 'failed')
        return false
    end
    local pending=G.pending
    if not pending then return end
    if text=="You can't find that person as they're hidden in one of their turfs." then
        complete(pending,"Can't find",'failed')
        return false
    elseif text=='You have already searched for someone - wait a little.' then
        complete(pending,'Cooldown - try again','pending')
        return false
    elseif text=='You are not a detective.' then
        complete(pending,'Detective job required','failed')
        return false
    end
end

function G:mention()
    if not can_mass_mention() or self.mass or self.collect or #self.rows==0 then return end
    local names,batches={},{}
    for _,row in ipairs(self.rows) do
        if same_player(row) then names[#names+1]=row.name end
    end
    table.sort(names,function(a,b)return #a==#b and a<b or #a>#b end)
    for _,name in ipairs(names)do
        local placed=false
        for i,line in ipairs(batches)do
            if #line+2+#name<=77 then batches[i]=line..', '..name;placed=true;break end
        end
        if not placed then batches[#batches+1]=name end
    end
    if #batches==0 then return end
    local posts={}
    for _,line in ipairs(batches)do posts[#posts+1]='/f '..line end
    posts[#posts+1]='/f YOU ARE NOT AT THE REGROUP, GET HERE ASAP'
    self.mass={posts=posts,index=1,next=0}
end

function G:register()
    sampRegisterChatCommand('rgcheck',function()self:run()end)
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)return {text}end,function(text)
        local snapshot=self.collect
        local plain=R.trim(R.strip(text))
        if snapshot and os.clock()-snapshot.started<=6 then
            if plain=='Members Online:' then snapshot.header=true;return false end
            if snapshot.header then
                local color,name,rank=text:match('^%* .- {(%x%x%x%x%x%x)}(.-){%x%x%x%x%x%x}%s+%((%d+)%)')
                if name then
                    color=color:upper();name=R.trim(R.strip(name))
                    local key=name_key(name)
                    if key==snapshot.local_name then snapshot.rank=tonumber(rank) end
                    snapshot.members[key]={name=name,jailed=color=='FF8000' or color=='6F570E'}
                    snapshot.last=os.clock();return false
                end
            end
        end
        return find_result(plain)
    end)
    shared.event_handler:register('SEND_COMMAND',function(command)
        return R.trim(command):lower()=='/members' and is_command_self_sent('members')
    end,function()self.collect=nil;self.error='Manual /members opened. Run /rgcheck again to refresh.'end)
    shared.event_handler:register('PED_TICK',function()return true end,function()
        local now=os.clock()
        if self.collect and ((self.collect.last and now-self.collect.last>=0.7) or now-self.collect.started>=6) then finish_members() end
        for key,request in pairs(self.requests) do
            if request.waiting and not same_player(request.row) then
                complete(request,'Offline','failed')
            elseif not request.waiting and now>=request.quiet_until then self.requests[key]=nil end
        end
        local mass=self.mass
        if mass and now>=mass.next then
            sampSendChat(mass.posts[mass.index]);mass.index=mass.index+1;mass.next=now+1
            if mass.index>#mass.posts then self.mass=nil end
        end
    end)
    imgui.OnFrame(function()return self.visible end,function()self:render()end)
end

local function draw_locked_mass_mention(size)
    imgui.PushStyleColor(imgui.Col.Button,imgui.ImVec4(0.30,0.30,0.30,1))
    imgui.BeginDisabled()
    imgui.Button('Mass mention',size)
    imgui.EndDisabled()
    imgui.PopStyleColor()

    local min,max=imgui.GetItemRectMin(),imgui.GetItemRectMax()
    imgui.GetWindowDrawList():AddLine(imgui.ImVec2(min.x+8,max.y-6),imgui.ImVec2(max.x-8,min.y+6),
        imgui.GetColorU32(imgui.ImVec4(1,0.22,0.22,0.85)),2)
end

function G:render()
    if self.open then imgui.OpenPopup('Regroup checker');self.open=false end
    local display=imgui.GetIO().DisplaySize
    imgui.SetNextWindowSize(imgui.ImVec2(math.min(550,display.x-32),math.min(650,display.y-48)),imgui.Cond.Always)
    if not imgui.BeginPopupModal('Regroup checker',nil,imgui.WindowFlags.NoResize+imgui.WindowFlags.NoScrollbar)then return end
    if self.collect then imgui.Text('Checking online members and your current area...') end
    if self.error then imgui.TextWrapped(self.error) end
    imgui.TextWrapped('Uses players currently streamed around you. Check uncertain names before using Mass mention.')
    local remaining=Find:cooldown_remaining()
    if remaining>0 then imgui.Text(('Find cooldown: %d seconds'):format(remaining)) end
    local height=math.max(80,imgui.GetContentRegionAvail().y-62)
    imgui.BeginChild('regroup_members',imgui.ImVec2(0,height),false)
    if not self.collect and not self.error and #self.rows==0 then imgui.Text('All online members checked are nearby.') end
    for i,row in ipairs(self.rows)do
        imgui.PushID(i)
        local button_x=imgui.GetCursorPosX()+imgui.GetContentRegionAvail().x-70
        imgui.BeginGroup()
        imgui.AlignTextToFramePadding()
        imgui.Text(('%s (%d)'):format(row.name,row.id))
        if row.location then
            local end_x=imgui.GetItemRectMax().x-imgui.GetWindowPos().x
            if end_x+imgui.GetStyle().ItemSpacing.x+imgui.CalcTextSize(row.location).x<button_x-8 then imgui.SameLine() end
            local color=row.result=='found' and imgui.ImVec4(0,1,0,1)
                or row.result=='pending' and imgui.ImVec4(1,0.5,0,1) or imgui.ImVec4(1,0,0,1)
            imgui.PushTextWrapPos(button_x-8)
            imgui.TextColored(color,row.location)
            imgui.PopTextWrapPos()
        end
        imgui.EndGroup()
        imgui.SameLine(button_x)
        if imgui.AnimButton('Find',imgui.ImVec2(70,0))then self:find(row)end
        if imgui.IsItemHovered() and remaining>0 then imgui.SetTooltip(('Cooldown: %d seconds'):format(remaining))end
        imgui.Separator();imgui.PopID()
    end
    imgui.EndChild();imgui.Separator()
    local mention_size=imgui.ImVec2(150,38)
    if can_mass_mention() then
        if imgui.AnimButton('Mass mention',mention_size) and #self.rows>0 and not self.collect and not self.mass then
            imgui.OpenPopup('Confirm mass mention')
        end
    else
        draw_locked_mass_mention(mention_size)
    end
    if imgui.IsItemHovered(imgui.HoveredFlags.AllowWhenDisabled) then
        imgui.SetTooltip('Only Rank 5 and Rank 6 are allowed to use this feature')
    end
    imgui.SameLine()
    if imgui.AnimButton('Close',imgui.ImVec2(150,38))then self.visible=false;imgui.CloseCurrentPopup()end
    if imgui.BeginPopupModal('Confirm mass mention',nil,imgui.WindowFlags.AlwaysAutoResize)then
        imgui.TextColored(imgui.ImVec4(1,0,0,1),'WARNING, this function spams every persons name, it may mute you')
        if imgui.AnimButton('Yes',imgui.ImVec2(100,0))then self:mention();imgui.CloseCurrentPopup()end
        imgui.SameLine();if imgui.AnimButton('No',imgui.ImVec2(100,0))then imgui.CloseCurrentPopup()end
        imgui.EndPopup()
    end
    imgui.EndPopup()
end
return G
