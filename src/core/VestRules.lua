local R=require('src.core.Rules')
local shared=require('src.shared')
local V={}
local registered,hospital,accept_after=nil,false,0
local small_markets={
    {-2967.8250,4413.9414,2525.0916},
    {-2967.7144,4413.8823,2525.0916},
    {-2967.6121,4413.9956,2525.0916},
    {-2967.7554,4414.0405,2525.0916},
}

function V.in_market(x,y,z)
    if z>=3091.9492 and z<=3118.9231 and x>=-838.8387 and x<=-788.4310
        and y>=1084.3008 and y<=1159.1694 then return true end
    for _,p in ipairs(small_markets) do
        if math.abs(z-p[3])<=12 and (x-p[1])^2+(y-p[2])^2<=36^2 then return true end
    end
    return false
end

local function available()
    return not hospital and doesCharExist(PLAYER_PED) and sampIsLocalPlayerSpawned()
        and not (isCharDead and isCharDead(PLAYER_PED))
        and not isCharPlayingAnim(PLAYER_PED,'KILL_Knife_Ped_Die')
end

function V.can_offer(aimed)
    if not available() then return false end
    if aimed then return true end
    local x,y,z=getCharCoordinates(PLAYER_PED)
    return not V.in_market(x,y,z)
end

function V.can_accept()
    return os.clock()>=accept_after and V.can_offer(false)
end

function V.register()
    if registered==shared.event_handler then return end
    registered=shared.event_handler
    hospital=false;accept_after=0
    local function admitted()
        hospital=true;accept_after=0
        shared.event_handler:process('HOSPITAL_ADMITTED')
    end
    shared.event_handler:register('LOCAL_DEATH',function()return true end,function()
        -- Clear old offers immediately. Hospital admission is confirmed by HZG's chat.
        shared.event_handler:process('HOSPITAL_ADMITTED')
    end)
    shared.event_handler:register('SERVER_MESSAGE',function(_,text)return {R.trim(R.strip(text))}end,function(text)
        if text=='You fell unconscious, you were immediately sent to the hospital.'
            or text=='You gave up hope and fell unconscious, you were immediately sent to the hospital.'
            or text=='Before you are discharged, hospital staff will confiscate your weapons.' then
            admitted()
        elseif text:match('^Your hospital bill comes to %$[%d,]+%. Have a nice day!$') then
            hospital=false
            local point=require('src.components.Points'):get_active_point()
            local turf=require('src.components.Turfs'):get_active_turf()
            local fighting=not point.refresh_timer:is_paused() or not turf.refresh_timer:is_paused()
            accept_after=fighting and os.clock()+15 or 0
        end
    end)
end
return V
