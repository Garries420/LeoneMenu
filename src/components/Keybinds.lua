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
local draft={entries={''},keys={}}
local entry_gap_ms=300
local function register(b)
    local running=false
    local function trigger()
        if not b.enabled[0] or running or #b.entries==0 then return end
        send_user_command(b.entries[1])
        if #b.entries==1 then return end

        running=true
        lua_thread.create(function()
            for i=2,#b.entries do
                wait(entry_gap_ms)
                if not b.enabled[0] or sampGetGamestate()~=3 or not sampIsLocalPlayerSpawned() then break end
                local ok,err=pcall(send_user_command,b.entries[i])
                if not ok then
                    print('[Leone Menu] Error in keybind: '..tostring(err))
                    break
                end
            end
            running=false
        end)
    end
    local name='custom_'..b.id
    if not shared.hotkey_manager:register(name,b.keys,trigger) then
        b.keys={}
        shared.hotkey_manager:register(name,b.keys,trigger)
    end
end
function K:register()
    Config.load(file,cfg)
    for _,b in ipairs(cfg.binds) do
        b.entries=b.entries or {b.command}
        b.command=nil
        local saved=b.enabled;b.enabled=imgui.new.bool(type(saved)=='table' and saved.__array and saved.__array[1]~=false or saved==true)
        b.keys=b.keys or {};register(b);cfg.next_id=math.max(cfg.next_id,b.id+1)
    end
    shared.hotkey_manager:register('custom_draft',{},function() end)
    MainWindow:add_page('keybinds',{title='Keybinds',icon=fa('KEYBOARD'),render_function=function() K:render_ui_settings() end})
end
function K:save_config() return Config.save(file,cfg) end

local function draw_entries()
    local entry_width=350
    local button_size=imgui.ImVec2(imgui.GetFrameHeight(),0)
    local hint='Add your text here...'
    draft.entries[1]=H.input('##custom_entry1',draft.entries[1],hint,entry_width,128)
    imgui.SameLine()
    if imgui.AnimButton('+##custom_entry_add',button_size) then
        draft.entries[#draft.entries+1]=''
        draft.scroll_to_end=true
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('if your keybinds requires more than 1 thing, press here') end

    if #draft.entries==1 then return end
    local style=imgui.GetStyle()
    local width=entry_width+style.ItemSpacing.x+button_size.x+style.ScrollbarSize
    local height=math.min(#draft.entries-1,6)*imgui.GetFrameHeightWithSpacing()
    if imgui.BeginChild('custom_extra_entries',imgui.ImVec2(width,height),false) then
        local remove
        for i=2,#draft.entries do
            draft.entries[i]=H.input('##custom_entry'..i,draft.entries[i],hint,entry_width,128)
            imgui.SameLine()
            if imgui.AnimButton('-##custom_entry_remove'..i,button_size) then remove=i end
        end
        if remove then table.remove(draft.entries,remove) end
        if draft.scroll_to_end then imgui.SetScrollHereY(1);draft.scroll_to_end=false end
    end
    imgui.EndChild()
end

local function draw_saved_binds()
    local style=imgui.GetStyle()
    local height=imgui.GetFrameHeight()
    local key_width=155
    local controls_width=imgui.ToggleButtonWidth()+key_width+height+2*style.ItemSpacing.x
    imgui.PushStyleVar(imgui.StyleVar.CellPadding,imgui.ImVec2(10,8))
    if not imgui.BeginTable('##saved_keybinds',2,imgui.TableFlags.RowBg+imgui.TableFlags.BordersInnerH) then
        imgui.PopStyleVar()
        return
    end
    imgui.TableSetupColumn('Entries',imgui.TableColumnFlags.WidthStretch)
    imgui.TableSetupColumn('Controls',imgui.TableColumnFlags.WidthFixed,controls_width)
    local remove
    for i,b in ipairs(cfg.binds) do
        imgui.PushID(b.id)
        imgui.TableNextRow(0,height+16)
        if imgui.TableNextColumn() then
            local start_x=imgui.GetCursorPosX()
            local wrap_x=start_x+imgui.GetContentRegionAvail().x
            local number_width=imgui.CalcTextSize(tostring(#b.entries)..'.').x+style.ItemSpacing.x
            imgui.SetCursorPosY(imgui.GetCursorPosY()+(height-imgui.GetTextLineHeight())/2)
            imgui.PushTextWrapPos(wrap_x)
            for index,entry in ipairs(b.entries) do
                if #b.entries>1 then
                    imgui.TextDisabled(tostring(index)..'.')
                    imgui.SameLine(start_x+number_width)
                end
                imgui.TextUnformatted(entry)
            end
            imgui.PopTextWrapPos()
        end
        if imgui.TableNextColumn() then
            imgui.ToggleButton('##enabled',b.enabled)
            imgui.SameLine()
            local keys=shared.hotkey_manager:draw_key_editor('custom_'..b.id,imgui.ImVec2(key_width,0))
            if keys then b.keys=keys end
            imgui.SameLine()
            if imgui.AnimButton(fa('TRASH'),imgui.ImVec2(height,0)) then remove=i end
        end
        imgui.PopID()
    end
    imgui.EndTable()
    imgui.PopStyleVar()
    if remove then
        local b=table.remove(cfg.binds,remove)
        b.enabled[0]=false
        shared.hotkey_manager:unregister('custom_'..b.id)
        K:save_config()
    end
end

function K:render_ui_settings()
    imgui.Text('Keybinds:')
    local area=imgui.GetContentRegionAvail()
    if imgui.BeginChild('custom_binds',imgui.ImVec2(0,math.max(120,area.y-48)),true) then draw_saved_binds() end
    imgui.EndChild()
    if imgui.AnimButton('Add') then draft={entries={''},keys={}};shared.hotkey_manager.registered.custom_draft.keys={};imgui.OpenPopup('Add Keybind') end
    if imgui.BeginPopupModal('Add Keybind',nil,imgui.WindowFlags.AlwaysAutoResize) then
        draw_entries()
        local keys=shared.hotkey_manager:draw_key_editor('custom_draft',imgui.ImVec2(180,0));if keys then draft.keys=keys end
        if imgui.AnimButton('Save') then
            local entries,valid={},true
            for _,entry in ipairs(draft.entries) do
                if entry:find('[\r\n]') then valid=false;break end
                if entry:find('%S') then entries[#entries+1]=entry end
            end
            if not valid or #entries==0 or #draft.keys==0 then msg('Enter text or a command and choose a keybind.')
            else
                shared.hotkey_manager.registered.custom_draft.keys={}
                local b={id=cfg.next_id,entries=entries,keys=draft.keys,enabled=imgui.new.bool(true)}
                cfg.next_id=cfg.next_id+1;cfg.binds[#cfg.binds+1]=b;register(b);self:save_config();imgui.CloseCurrentPopup()
            end
        end
        imgui.SameLine();if imgui.AnimButton('Cancel') then shared.hotkey_manager.registered.custom_draft.keys={};imgui.CloseCurrentPopup() end
        imgui.EndPopup()
    end
end
return K
