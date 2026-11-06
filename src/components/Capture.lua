local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local shared=require('src.shared')
local R=require('src.core.Rules')
local locations=require('src.core.CustomLocations')
local Points=require('src.components.Points')
local C={}
local attendance={name='',flagged=false,next=0}
local last_end={}
local function key(name) return R.trim(name:lower():gsub('^the ','')) end
local warning='!!!!!!POINT IS OVER STOP SHOOTING!!!!!!'

local function check_attendance(name,x,y,z,interior)
    if attendance.name~=name then attendance={name=name,flagged=false} end
    if attendance.flagged then return end
    attendance.interior=interior
    attendance.next=os.clock()+1
    attendance.flagged=locations.find(x,y,z,interior,true)~=nil
end
local function ended(name)
    local k=key(name);local now=os.clock()
    if last_end[k] and now-last_end[k]<5 then return end
    last_end[k]=now
    local point=Points:get_active_point()
    if not point.refresh_timer:is_paused() and key(point.name)==k and doesCharExist(PLAYER_PED) then
        -- A player already inside at the end counts even between samples.
        local x,y,z=getCharCoordinates(PLAYER_PED)
        check_attendance(k,x,y,z,getActiveInterior())
    end
    local flagged=attendance.flagged and attendance.name==k
    if attendance.name==k then attendance={name='',flagged=false} end
    -- Requested for every point end, including players who never attended.
    for i=1,5 do sampAddChatMessage('{FF0000}'..warning,0xFFFF0000) end
    if flagged and not isCharInAnyCar(PLAYER_PED) then
        require('src.ui.Dialogs').show('Leone Menu - Point ended','\n\t{FF0000}'..warning..'\n',0,'OK',nil,true,function() return not isCharInAnyCar(PLAYER_PED) end)
    end
end
function C:register()
    require('src.ui.MainWindow'):add_page('capture',{title='Turfs & Points',icon=fa('MAP'),render_function=function()
        require('src.components.Turfs'):render_ui_settings()
        require('src.components.Points'):render_ui_settings()
        H.position({require('src.components.Turfs'):get_overlay_config()},'capture')
    end})
    shared.event_handler:register('POINT_ENDED',function(name) return {name} end,ended)
    shared.event_handler:register('SERVER_MESSAGE',function(color,text)
        local name=R.strip(text):match('^.- has taken control of the (.-) for .-%.$')
        return name and {name} or false
    end,ended)
    shared.event_handler:register('PED_TICK',function(x,y,z)
        local point=Points:get_active_point()
        if point.name=='' or point.refresh_timer:is_paused() then return false end
        local interior=getActiveInterior()
        local name=key(point.name)
        if attendance.name==name and (attendance.flagged
            or (interior==0 and attendance.interior==0 and os.clock()<attendance.next)) then return false end
        return {name,x,y,z,interior}
    end,check_attendance)
end
return C
