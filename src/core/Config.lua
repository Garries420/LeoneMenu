-- Leone persistence; preserves Sputnik's table/cdata settings API.
local ffi = require('ffi')
local json = require('dkjson')
local Config = {}
local function encode_value(v)
    if type(v) == 'cdata' then
        local n = assert(tonumber(tostring(ffi.typeof(v)):match('%[(%d+)%]')), 'Unsupported config cdata')
        local a = {}
        for i=0,n-1 do
            if type(v[i])=='boolean' then a[i+1]=v[i] else a[i+1]=tonumber(v[i]) end
        end
        return {__array=a}
    elseif type(v) == 'table' then
        local out = {}
        for k,x in pairs(v) do out[k] = encode_value(x) end
        return out
    end
    return v
end
local function merge(target, data)
    for source_key,v in pairs(data) do
        local k=source_key
        if type(k)=='string' and tonumber(k) and target[tonumber(k)]~=nil then k=tonumber(k) end
        local old = target[k]
        if type(old) == 'cdata' and type(v) == 'table' and type(v.__array) == 'table' then
            local n = assert(tonumber(tostring(ffi.typeof(old)):match('%[(%d+)%]')), 'Unsupported config cdata')
            for i=0,n-1 do
                local x=v.__array[i+1]
                -- Older builds lost false bools and saved an empty __array.
                if x==nil and type(old[i])=='boolean' then old[i]=false
                elseif type(x)==type(old[i]) then old[i]=x end
            end
        elseif type(old)=='table' and type(v)=='table' and not v.__array then merge(old,v)
        elseif old==nil or type(old)==type(v) then target[k]=v end
    end
end
local Files=require('src.utils.UpdateFiles')
Config.path=Files.path
Config.read=Files.read
Config.write=Files.write

function Config.save(path, settings)
    local ok,data=pcall(function() return json.encode(encode_value(settings),{indent=true}) end)
    if not ok then return false,data end
    local old=Config.read(path)
    if old==data then return true end
    if old and type(json.decode(old))=='table' then Config.write(path..'.bak',old) end
    local success,err=Config.write(path,data)
    if not success then print('[Leone Menu] Config save failed: '..tostring(err)) end
    return success,err
end
function Config.load(path, settings)
    local data=Config.read(path)
    if not data then return Config.save(path,settings) end
    local parsed,_,err=json.decode(data)
    if type(parsed)~='table' or err then
        print('[Leone Menu] Invalid config; trying backup: '..path)
        parsed=json.decode(Config.read(path..'.bak') or '')
    end
    if type(parsed)=='table' then merge(settings,parsed) end
    return true
end
return Config
