local Config=require('src.core.Config')
local R=require('src.core.Rules')
local Http=require('src.utils.AsyncHttpRequest')
local json=require('dkjson')
local U={version='1.0.3',runtime=5,status='Menu update check pending',skins_status='Using bundled alliance skins',busy=false,skins_busy=false}
local base='https://garries420.github.io/LeoneMenu/'
local menu_url=base..'LeoneMenu.lua'
local cache='config/Leone Menu/alliance-skins.html'
local initial={132,137,209,212,230,236,107,195,270,269,271,106,293,0,68,200,62,221,229,214,127,124,24,164,202,66,234,235,261,272,43,91,2,291,93,101,233,126,211}
U.alliance={version=2,skins=initial}
U.sha256=require('src.utils.UpdateFiles').sha256
function U.is_alliance(id) for _,v in ipairs(U.alliance.skins) do if v==id then return true end end return false end
function U.check_skins(manual)
    if U.skins_busy then return end
    U.skins_busy=true
    U.skins_status='Checking alliance skins...'
    local function finish(status)
        U.skins_status=status
        U.skins_busy=false
        if manual then msg(U.skins_status) end
    end
    local function unavailable() finish('Using the last available alliance skin list') end
    Http:new('GET',base..'skins/latest.json',nil,20):then_(function(res)
        local m=res.status_code==200 and json.decode(res.text)
        if type(m)~='table' or type(m.version)~='number' or m.version%1~=0 or type(m.path)~='string'
            or not m.path:match('^skins/alliance%-skins%-%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_CES?T%.html$')
            or type(m.sha256)~='string' or #m.sha256~=64 or not m.sha256:match('^%x+$') then return unavailable() end
        if m.version<=U.alliance.version and U.alliance.date then return finish('Alliance skins are current') end
        Http:new('GET',base..m.path,nil,20):then_(function(page)
            local parsed=page.status_code==200 and U.sha256(page.text)==m.sha256:lower() and R.alliance(page.text)
            if not parsed or not parsed.date or parsed.version~=m.version or parsed.version<U.alliance.version then return unavailable() end
            if not Config.write(cache,page.text) then return finish('Could not save skin update; previous list retained') end
            U.alliance=parsed
            finish('Alliance skins updated')
        end):catch(unavailable)
    end):catch(unavailable)
end
local function install(manifest)
    U.status='Downloading version '..manifest.version
    Http:new('GET',menu_url,nil,30):then_(function(res)
        if res.status_code~=200 or #res.text<1000 or U.sha256(res.text)~=manifest.sha256:lower() then U.status='Update verification failed; current menu kept';return end
        local compiled=loadstring(res.text,'@LeoneMenu-update')
        if not compiled or not res.text:find('LEONE_MENU_BUNDLE',1,true) then U.status='Invalid update; current menu kept';return end
        local target=thisScript().path
        local old=Config.read(target)
        if not old then U.status='Could not read current script';return end
        local ok=Config.write('config/Leone Menu/LeoneMenu.previous.lua',old)
        if not ok then U.status='Could not save rollback copy';return end
        ok=Config.write(target,res.text)
        if not ok then U.status='Could not replace script; current menu kept';return end
        U.status='Installed Leone Menu '..manifest.version
        require('src.components.Home').reload_requested='update'
    end):catch(function() U.status='Update download failed; current menu kept' end):finally(function() U.busy=false end)
end
function U.check_menu(manual)
    if U.busy then return end
    U.busy=true;U.status='Checking for updates...'
    Http:new('GET',base..'leone-update.json',nil,20):then_(function(res)
        local m=res.status_code==200 and json.decode(res.text)
        if res.status_code==404 then
            U.status='Menu updates are waiting for the GitHub feed';U.busy=false
        elseif type(m)~='table' or type(m.version)~='string' or type(m.sha256)~='string'
            or not m.sha256:match('^%x+$') or #m.sha256~=64 or m.url~=menu_url then
            U.status='Could not verify the update feed; keeping '..U.version;U.busy=false
        elseif not R.newer(m.version,U.version) then U.status='Leone Menu is up to date ('..U.version..')';U.busy=false
        else install(m) end
        if manual then msg(U.status) end
    end):catch(function() U.status='Could not check updates; menu works offline';U.busy=false end)
end
function U.start(can_update)
    local bundled=Config.read('resource/Leone Menu/alliance-skins.html')
    local fallback=bundled and R.alliance(bundled)
    if fallback and fallback.version>=U.alliance.version then U.alliance=fallback end
    local saved=Config.read(cache)
    local parsed=saved and R.alliance(saved)
    if parsed and parsed.version>=U.alliance.version then U.alliance=parsed end
    lua_thread.create(function()
        while not can_update() do wait(100) end
        print('[Leone Menu] Startup notice finished. Checking for updates.')
        U.check_menu(false);U.check_skins(false)
        while true do wait(3600000);U.check_skins(false) end
    end)
end
return U
