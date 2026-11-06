-- Retains Sputnik's shared hotkey editor and execution manager.
local imgui=require('upmimgui')
local fa=require('fAwesome7')
local Config=require('src.core.Config')
local MainWindow=require('src.ui.MainWindow')
local shared=require('src.shared')
local H=require('src.ui.Helpers')
local K={}
local cfg={binds={},next_id=1}
local file='config/Leone Menu/keybinds.json'
local draft={command='',keys={}}
local function register(b)
    local ok=shared.hotkey_manager:register('custom_'..b.id,b.keys,function() if b.enabled[0] then send_user_command(b.command) end end)
    if not ok then b.keys={};shared.hotkey_manager:register('custom_'..b.id,{},function() if b.enabled[0] then send_user_command(b.command) end end) end
end
function K:register()
    Config.load(file,cfg)
    for _,b in ipairs(cfg.binds) do
        local saved=b.enabled;b.enabled=imgui.new.bool(type(saved)=='table' and saved.__array and saved.__array[1]~=false or saved==true)
        b.keys=b.keys or {};register(b);cfg.next_id=math.max(cfg.next_id,b.id+1)
    end
    shared.hotkey_manager:register('custom_draft',{},function() end)
    MainWindow:add_page('keybinds',{title='Keybinds',icon=fa('KEYBOARD'),render_function=function() K:render_ui_settings() end})
end
function K:save_config() return Config.save(file,cfg) end
function K:render_ui_settings()
    imgui.Text('Keybinds:')
    local area=imgui.GetContentRegionAvail()
    imgui.BeginChild('custom_binds',imgui.ImVec2(0,math.max(120,area.y-48)),true)
    for i,b in ipairs(cfg.binds) do
        imgui.PushID(b.id)
        local width=imgui.GetContentRegionAvail().x
        imgui.Text(b.command);imgui.SameLine(width-205-imgui.ToggleButtonWidth()-10)
        imgui.ToggleButton('##enabled',b.enabled);imgui.SameLine(width-205)
        local keys=shared.hotkey_manager:draw_key_editor('custom_'..b.id,imgui.ImVec2(155,0));if keys then b.keys=keys end
        imgui.SameLine(width-40)
        if imgui.AnimButton(fa('TRASH')) then shared.hotkey_manager:unregister('custom_'..b.id);table.remove(cfg.binds,i);self:save_config() end
        imgui.PopID()
    end
    imgui.EndChild()
    if imgui.AnimButton('Add') then draft.command='';draft.keys={};shared.hotkey_manager.registered.custom_draft.keys={};imgui.OpenPopup('Add Keybind') end
    if imgui.BeginPopupModal('Add Keybind',nil,imgui.WindowFlags.AlwaysAutoResize) then
        draft.command=H.input('##custom_command',draft.command,'/dance 1',350,128)
        local keys=shared.hotkey_manager:draw_key_editor('custom_draft',imgui.ImVec2(180,0));if keys then draft.keys=keys end
        if imgui.AnimButton('Save') then
            if not draft.command:match('^/%S+') or draft.command:find('[\r\n]') or #draft.keys==0 then msg('Enter a command beginning with / and choose a keybind.')
            else
                shared.hotkey_manager.registered.custom_draft.keys={}
                local b={id=cfg.next_id,command=draft.command,keys=draft.keys,enabled=imgui.new.bool(true)}
                cfg.next_id=cfg.next_id+1;cfg.binds[#cfg.binds+1]=b;register(b);self:save_config();imgui.CloseCurrentPopup()
            end
        end
        imgui.SameLine();if imgui.AnimButton('Cancel') then shared.hotkey_manager.registered.custom_draft.keys={};imgui.CloseCurrentPopup() end
        imgui.EndPopup()
    end
end
return K
