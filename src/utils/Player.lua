-- Module: F:\2025\EDrive\dev\luapack\src\utils\Player.lua

local Player = {}
Player.VEST_RANGE = 6

function Player:resolve_player_id(args,quiet)
    local players={}
    for id=0,sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then players[#players+1]={id=id,name=sampGetPlayerNickname(id)} end
    end
    local found=require('src.core.Rules').matches(args,players)
    if #found==1 then return found[1].id end
    if not quiet then
        if #found==0 then msg("Player isn't logged in or ID/name is wrong, try again")
        else
            msg('Several players match that name. Use their ID:')
            for _,p in ipairs(found) do msg(string.format('%s ({1E3348}%d{FFFFFF})',p.name:gsub('_',' '),p.id)) end
        end
    end
    return nil
end

function Player:get_closest_player_id(max_distance, filters)
    local closest_id, closest_distance = nil, max_distance
    local l_px, l_py, l_pz = getCharCoordinates(PLAYER_PED)
    for i = 0, sampGetMaxPlayerId(true) do
        local ok, ped = sampGetCharHandleBySampPlayerId(i)
        if ok then
            local passed = true
            if filters then
                for _, filter in ipairs(filters) do
                    if not filter(i, ped) then
                        passed = false
                        break
                    end
                end
            end
            if passed then
                local px, py, pz = getCharCoordinates(ped)
                if is_within_distance_3d(px, py, pz, l_px, l_py, l_pz, closest_distance) then
                    local dx = px - l_px
                    local dy = py - l_py
                    local dz = pz - l_pz
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                    if closest_id == nil or dist < closest_distance then
                        closest_id = i
                        closest_distance = dist
                    end
                end
            end
        end
    end
    return closest_id ~= nil, closest_id
end

function Player:get_player_id_by_name(player_name)
    local local_player, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)

    if local_player and player_name == sampGetPlayerNickname(my_id) then
        return my_id
    end

    for player_id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(player_id) then
            local name = sampGetPlayerNickname(player_id)
            if name == player_name then
                return player_id
            end
        end
    end
    return nil
end

function Player:is_on_admin_duty()
    local my_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local nickname = sampGetPlayerNickname(my_id)

    return not nickname:find("_")
end

function Player:is_valid_samp_name(name)
    local len = #name
    return len >= 3 and len <= 24
        and not name:find("%s")
        and name:find("_")
        and name:match("^[A-Za-z0-9_.]+$")
end

return Player
