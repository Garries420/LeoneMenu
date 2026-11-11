local imgui=require('upmimgui')
local fa=require('fAwesome7')
local H=require('src.ui.Helpers')
local R=require('src.core.Rules')
local Import=require('src.core.GangImport')
local Picker=require('src.ui.SkinPicker')
local E={}
local function clear_fields(editor)
    editor.name='';editor.hex='';editor.skins='';editor.index=nil;editor.error=nil
end
function E:show(groups,on_save)
    self.groups={}
    for i,g in ipairs(groups)do self.groups[i]=g end
    self.on_save=on_save;self.open=true
    clear_fields(self)
end
local function color(hex)
    local n=tonumber(hex,16) or 0
    return imgui.ImVec4(math.floor(n/65536)/255,math.floor(n/256)%256/255,n%256/255,1)
end
function E:render()
    if self.open then imgui.OpenPopup('Add gang');self.open=false end
    local display=imgui.GetIO().DisplaySize
    local width=math.min(460,display.x-32)
    local height=math.min(740,display.y-48)
    imgui.SetNextWindowSize(imgui.ImVec2(width,height),imgui.Cond.Always)
    if not imgui.BeginPopupModal('Add gang',nil,imgui.WindowFlags.NoResize+imgui.WindowFlags.NoScrollbar+imgui.WindowFlags.NoScrollWithMouse)then return end
    local avail=imgui.GetContentRegionAvail()
    imgui.BeginChild('gang_editor_body',imgui.ImVec2(0,math.max(80,avail.y-58)),false)
    if imgui.AnimButton(fa('SHIRT')..' Skins') then
        Picker:show(R.skins(self.skins) or {},function(ids)self.skins=table.concat(ids,', ')end)
    end
    if imgui.IsItemHovered()then imgui.SetTooltip('Choose skins by clicking their images.')end
    imgui.SameLine()
    if imgui.AnimButton('Auto import')then Import:toggle()end
    if imgui.IsItemHovered()then imgui.SetTooltip('Displays every available gangs from /gangs. pick one and it auto chooses its name and color code')end
    if Import.visible then
        if Import.importing then imgui.TextDisabled('Importing gangs...')end
        for i,g in ipairs(Import.rows)do
            imgui.PushStyleColor(imgui.Col.Text,color(g.hex))
            if imgui.Selectable(g.name..'##import'..i,false,imgui.SelectableFlags.NoAutoClosePopups)then
                self.name=g.name;self.hex=g.hex;self.error=nil;Import.visible=false
            end
            imgui.PopStyleColor()
        end
        if not Import.importing and #Import.rows==0 then imgui.TextDisabled('No gang list yet. Try Auto import again.')end
        imgui.Separator()
    end
    local field_width=imgui.GetContentRegionAvail().x
    imgui.Text('Name');self.name=H.input('##gang_name',self.name,'Gang name',field_width,40)
    imgui.Text('Hex color code');self.hex=H.input('##gang_hex',self.hex,'1E3348',field_width-44,6)
    imgui.SameLine();imgui.ColorButton('##color_preview',color(self.hex))
    imgui.Text('Skins (ID)');self.skins=H.input('##gang_skins',self.skins,'1, 2, 3, 10, 11, 22, 35',field_width,2048)
    if imgui.IsItemHovered()then imgui.SetTooltip('Format: 1, 2, 3, 10, 11, 22, 35')end
    if imgui.AnimButton('Add')then
        local name=R.trim(self.name)
        local ids=R.skins(self.skins)
        if name=='' or not self.hex:match('^%x%x%x%x%x%x$') or not ids then
            self.error='Enter a name, six HEX digits and valid skin IDs.'
        else
            self.groups[self.index or (#self.groups+1)]={name=name,hex=self.hex:upper(),skins=ids}
            clear_fields(self)
        end
    end
    if self.error then imgui.TextWrapped(self.error)end
    if #self.groups>0 then
        imgui.Separator();imgui.Text('Groups')
        for i,g in ipairs(self.groups)do
            imgui.PushID(i)
            if imgui.AnimButton(fa('TRASH')..'##remove')then
                table.remove(self.groups,i)
                clear_fields(self)
            else
                imgui.SameLine()
                if imgui.Selectable(g.name,false,imgui.SelectableFlags.NoAutoClosePopups)then
                    self.name=g.name;self.hex=g.hex;self.skins=table.concat(g.skins,', ');self.index=i;self.error=nil
                end
            end
            imgui.PopID()
        end
    end
    imgui.EndChild()
    imgui.Separator()
    local button_width=math.min(150,(imgui.GetContentRegionAvail().x-12)/2)
    if imgui.AnimButton('Save',imgui.ImVec2(button_width,38))then
        if self.on_save(self.groups) then imgui.CloseCurrentPopup()
        else self.error='Could not save groups. Please try again.' end
    end
    imgui.SameLine();if imgui.AnimButton('Cancel',imgui.ImVec2(button_width,38))then imgui.CloseCurrentPopup()end
    Picker:render()
    imgui.EndPopup()
end
return E
