local Config=require('src.core.Config')
local R=require('src.core.Rules')
local Http=require('src.utils.AsyncHttpRequest')
local json=require('dkjson')
local U={version='1.0.13',runtime=5,status='Menu update check pending',skins_status='Using bundled alliance skins',busy=false,skins_busy=false}
local base='https://garries420.github.io/LeoneMenu/'
local menu_url=base..'LeoneMenu.lua'
local cache='config/Leone Menu/alliance-skins.html'
local staged,completed,http_request
local startup_checked,manual_queued,manual_skins=false,false,false
local next_skins_at=0
local initial={68,94,62,221,214,229,234,235,261,272,43,91,132,137,209,212,230,236,24,25,124,69,164,202,107,195,270,269,271,106}
U.alliance={version=2,skins=initial}
U.sha256=require('src.utils.UpdateFiles').sha256
function U.is_alliance(id) for _,v in ipairs(U.alliance.skins) do if v==id then return true end end return false end
local function request(url,timeout,success,failure)
    local ok,err=pcall(function()
        http_request=Http:new('GET',url,nil,timeout,true):then_(function(response)
            completed=function() success(response) end
        end):catch(function()
            completed=failure
        end)
    end)
    if not ok then
        print('[Leone Menu] Could not start update request: '..tostring(err))
        completed=failure
    end
end
function U.check_skins(manual)
    if U.skins_busy or U.busy then return end
    U.skins_busy=true
    U.skins_status='Checking alliance skins...'
    local function finish(status)
        U.skins_status=status
        U.skins_busy=false
        if manual then msg(U.skins_status) end
    end
    local function unavailable() finish('Using the last available alliance skin list') end
    request(base..'skins/latest.json',20,function(res)
        local m=res.status_code==200 and json.decode(res.text)
        if type(m)~='table' or type(m.version)~='number' or m.version%1~=0 or type(m.path)~='string'
            or not m.path:match('^skins/alliance%-skins%-%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_CES?T%.html$')
            or type(m.sha256)~='string' or #m.sha256~=64 or not m.sha256:match('^%x+$') then return unavailable() end
        if m.version<=U.alliance.version and U.alliance.date then return finish('Alliance skins are current') end
        request(base..m.path,20,function(page)
            local parsed=page.status_code==200 and U.sha256(page.text)==m.sha256:lower() and R.alliance(page.text)
            if not parsed or not parsed.date or parsed.version~=m.version or parsed.version<U.alliance.version then return unavailable() end
            if not Config.write(cache,page.text) then return finish('Could not save skin update; previous list retained') end
            U.alliance=parsed
            finish('Alliance skins updated')
        end,unavailable)
    end,unavailable)
end
local function download(manifest)
    U.status='Downloading version '..manifest.version
    request(menu_url,30,function(res)
        U.busy=false
        if res.status_code~=200 or #res.text<1000 or U.sha256(res.text)~=manifest.sha256:lower() then U.status='Update verification failed; current menu kept';return end
        local compiled=loadstring(res.text,'@LeoneMenu-update')
        if not compiled or not res.text:find('LEONE_MENU_BUNDLE',1,true) then U.status='Invalid update; current menu kept';return end
        staged={version=manifest.version,text=res.text}
    end,function() U.status='Update download failed; current menu kept';U.busy=false end)
end

local function replace_script(text)
    local target=thisScript().path
    local old=Config.read(target)
    if not old then return false,'Could not read current script' end
    if not Config.write('config/Leone Menu/LeoneMenu.previous.lua',old) then return false,'Could not save rollback copy' end
    if not Config.write(target,text) then return false,'Could not replace script; current menu kept' end
    return true
end

local function install_staged()
    local update=staged
    staged=nil
    local ok,replaced,why=pcall(replace_script,update.text)
    if not ok then print('[Leone Menu] Update file replacement failed: '..tostring(replaced)) end
    if not ok or not replaced then
        U.status=why or 'Could not install the update; current menu kept'
        return
    end
    U.restart_required=true
    U.status='Leone Menu '..update.version..' installed. Restart GTA to apply the update.'
    print('[Leone Menu] '..U.status)
    msg(U.status)
    require('src.ui.MainWindow'):hide()
    require('src.ui.Dialogs').show('Leone Menu - Restart required',table.concat({
        '{FFFFFF}Leone Menu {00FF00}'..update.version..'{FFFFFF} has finished installing.',
        '',
        '{FF0000}YOU MUST FULLY CLOSE AND REOPEN GTA.',
        '{FFFFFF}Close GTA San Andreas, then launch SA-MP and reconnect.',
        '',
        '{FF0000}Reloading Lua scripts (CTRL + R) is NOT enough.',
        '{FFFFFF}Disconnecting and reconnecting without closing GTA is NOT enough.',
        '',
        'The update will take effect after GTA has restarted.',
        'Press OK to acknowledge.',
    },'\n'),0,'OK',nil,true,nil,'update_restart_required')
end

function U.check_menu(manual)
    if U.busy or U.skins_busy or staged or U.restart_required then return end
    U.busy=true;U.status='Checking for updates...'
    request(base..'leone-update-v2.json',20,function(res)
        local m=res.status_code==200 and json.decode(res.text)
        if res.status_code==404 then
            U.status='Menu updates are waiting for the GitHub feed';U.busy=false
        elseif type(m)~='table' or type(m.version)~='string' or type(m.sha256)~='string'
            or not m.sha256:match('^%x+$') or #m.sha256~=64 or m.url~=menu_url then
            U.status='Could not verify the update feed; keeping '..U.version;U.busy=false
        elseif not R.newer(m.version,U.version) then U.status='Leone Menu is up to date ('..U.version..')';U.busy=false
        else download(m) end
        if manual then msg(U.status) end
    end,function() U.status='Could not check updates; menu works offline';U.busy=false end)
end
function U.start()
    local bundled=Config.read('resource/Leone Menu/alliance-skins.html')
    local fallback=bundled and R.alliance(bundled)
    if fallback and fallback.version>=U.alliance.version then U.alliance=fallback end
    local saved=Config.read(cache)
    local parsed=saved and R.alliance(saved)
    if parsed and parsed.version>=U.alliance.version then U.alliance=parsed end
end

function U.request_check()
    if U.busy or U.skins_busy then return end
    manual_queued=true
    if not startup_checked then U.status='Update check queued until startup finishes' end
end

function U.tick(ready)
    if not ready then return end
    if http_request and http_request:poll() then http_request=nil end
    if completed then
        local handle=completed
        completed=nil
        handle()
    end
    if U.busy or U.skins_busy then return end
    if staged then install_staged() end
    local now=os.clock()
    if not startup_checked or manual_queued then
        if not startup_checked then print('[Leone Menu] Startup notice finished. Checking for updates.') end
        startup_checked=true
        manual_skins=manual_queued
        manual_queued=false
        next_skins_at=now
        U.check_menu(manual_skins)
    elseif now>=next_skins_at then
        next_skins_at=now+3600
        U.check_skins(manual_skins)
        manual_skins=false
    end
end
return U
