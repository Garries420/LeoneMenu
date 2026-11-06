local Player=require('src.utils.Player')
local Rules=require('src.core.Rules')
local events=require('src.shared').event_handler
local Frisk={}
local request,stream,playing

local function normalized(name) return Rules.trim(name):gsub('_',' '):lower() end

local function release()
    if stream then releaseAudioStream(stream);stream=nil end
    playing=false
end

function Frisk.play()
    if playing then return end
    playing=true
    lua_thread.create(function()
        local ok,handle=pcall(loadAudioStream,getWorkingDirectory()..'/resource/Leone Menu/Sniperwarning.mp3')
        if ok and handle and handle~=0 then
            stream=handle
            setAudioStreamState(stream,1)
            wait(4000)
        end
        release()
    end)
end

function Frisk.register(enabled)
    events:register('SEND_COMMAND',function(command)
        local target=command:match('^/frisk%s+(.+)$')
        return target and {target}
    end,function(target)
        local id=Player:resolve_player_id(target,true)
        request=id and {name=normalized(sampGetPlayerNickname(id)),expires=os.clock()+8}
    end)
    events:register('SERVER_MESSAGE',function(_,text)
        return enabled[0] and request and os.clock()<=request.expires and {Rules.trim(Rules.strip(text))}
    end,function(text)
        local header=text:match('^%*%*%*%s+(.-)\'s? weapons%.%.%.%s+%*%*%*$')
        if header then request.weapons=normalized(header)==request.name;return end
        if request.weapons and text=='Weapon: Sniper Rifle.' then request.sniper=true;return end
        local officer,target=text:match('^%* (.-) has frisked (.-)%.$')
        if not officer or normalized(target)~=request.name then return end
        local connected,my_id=sampGetPlayerIdByCharHandle(PLAYER_PED)
        if not connected or normalized(sampGetPlayerNickname(my_id))~=normalized(officer) then return end
        local sniper=request.sniper
        request=nil
        if sniper then Frisk.play() end
    end)
    addEventHandler('onScriptTerminate',function(scr)
        if scr==script.this then release() end
    end)
end

return Frisk
