-- Five-minute in-session cache; hiding the list never repeats /gangs.
local R=require('src.core.Rules')
local shared=require('src.shared')
local G={rows={},visible=false,importing=false,cached_at=nil,last_request=-300}
function G:toggle()
    self.visible=not self.visible
    if not self.visible or self.importing then return end
    local now=os.clock()
    if self.cached_at and now-self.cached_at<300 then return end
    if now-self.last_request<6 then return end
    self.buffer={};self.importing=true;self.started=now;self.last=nil;self.last_request=now
    samp_send_hidden_command('gangs')
end
local function finish()
    G.importing=false
    if #G.buffer>0 then G.rows=G.buffer;G.cached_at=os.clock() end
    G.buffer=nil;G.last=nil
end
shared.event_handler:register('SERVER_MESSAGE',function(color,text)
    return G.importing and {color,text} or false
end,function(color,text)
    if os.clock()-G.started>6 then finish();return end
    local row=R.gang(text,color)
    if row then
        for _,g in ipairs(G.buffer) do if g.name==row.name then return false end end
        G.buffer[#G.buffer+1]=row;G.last=os.clock();return false
    end
    if R.trim(R.strip(text))=='Gangs:' then return false end
end)
shared.event_handler:register('PED_TICK',function()return G.importing end,function()
    if (G.last and os.clock()-G.last>0.6) or os.clock()-G.started>6 then finish() end
end)
return G
