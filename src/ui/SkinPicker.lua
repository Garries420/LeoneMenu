local imgui=require('upmimgui')
local H=require('src.ui.Helpers')
local catalog=require('src.core.SkinCatalog')
local S={open=false,query='',textures={},selected={},ids={}}
function S:show(ids,on_done)
    self.open=true;self.query='';self.on_done=on_done;self.ids={};self.selected={}
    for _,id in ipairs(ids)do if not self.selected[id]then self.ids[#self.ids+1]=id;self.selected[id]=true end end
end
function S:toggle(id)
    if self.selected[id]then
        self.selected[id]=nil
        for i,n in ipairs(self.ids)do if n==id then table.remove(self.ids,i);break end end
    else self.selected[id]=true;self.ids[#self.ids+1]=id end
end
function S:render()
    if not self.open then return end
    if not imgui.IsPopupOpen('Skin images')then imgui.OpenPopup('Skin images')end
    local display=imgui.GetIO().DisplaySize
    local width=math.min(1240,display.x-40)
    local height=math.min(1000,display.y-40)
    local columns=math.max(1,math.min(6,math.floor((width-36)/195)))
    imgui.SetNextWindowSize(imgui.ImVec2(width,height),imgui.Cond.Always)
    local flags=imgui.WindowFlags.NoResize+imgui.WindowFlags.NoScrollbar+imgui.WindowFlags.NoScrollWithMouse
    if imgui.BeginPopupModal('Skin images',nil,flags)then
        self.query=H.input('##skin_search',self.query,'Search skin ID',imgui.GetContentRegionAvail().x,3)
        local available=imgui.GetContentRegionAvail()
        imgui.BeginChild('skin_grid',imgui.ImVec2(0,math.max(80,available.y-124)),false)
        if imgui.BeginTable('skins',columns)then
            for _,s in ipairs(catalog)do
                if self.query=='' or tostring(s.id):find(self.query,1,true)then
                    imgui.TableNextColumn();imgui.PushID(s.id)
                    local visible=imgui.IsRectVisible(imgui.ImVec2(s.width,s.height))
                    if self.textures[s.id]==nil and visible then
                        local folder=(s.id==1 or s.id==2)and 'skin-overrides/' or 'skins/'
                        local ok,tex=pcall(imgui.CreateTextureFromFile,getWorkingDirectory()..'/resource/Leone Menu/'..folder..s.id..'.png')
                        self.textures[s.id]=ok and tex or false
                    end
                    local origin=imgui.GetCursorScreenPos()
                    local size=imgui.ImVec2(s.width,s.height)
                    local finish=imgui.ImVec2(origin.x+size.x,origin.y+size.y)
                    imgui.InvisibleButton('##skin',size)
                    local hovered=imgui.IsItemHovered()
                    if imgui.IsItemClicked(0)then self:toggle(s.id)end
                    local draw=imgui.GetWindowDrawList()
                    if hovered or self.selected[s.id]then
                        draw:AddRectFilled(origin,finish,imgui.GetColorU32(imgui.ImVec4(.17,.25,.33,hovered and .32 or .22)),8)
                    end
                    if self.textures[s.id]then draw:AddImage(self.textures[s.id],origin,finish)end
                    if self.selected[s.id]then draw:AddRect(origin,finish,imgui.GetColorU32(H.color),8,0,2)end
                    local label='ID '..s.id
                    local text=imgui.CalcTextSize(label)
                    local at=imgui.ImVec2(origin.x+(size.x-text.x)/2,origin.y+(size.y-text.y)/2)
                    draw:AddRectFilled(imgui.ImVec2(at.x-7,at.y-4),imgui.ImVec2(at.x+text.x+7,at.y+text.y+4),imgui.GetColorU32(imgui.ImVec4(0,0,0,.65)),5)
                    draw:AddText(at,0xFFFFFFFF,label)
                    imgui.PopID()
                end
            end
            imgui.EndTable()
        end
        imgui.EndChild()
        imgui.Separator()
        imgui.BeginChild('selected_skin_ids',imgui.ImVec2(0,54),false)
        imgui.TextWrapped('Selected IDs: '..(#self.ids>0 and table.concat(self.ids,', ')or 'None'))
        imgui.EndChild()
        local done_width=200
        imgui.SetCursorPosX((imgui.GetWindowWidth()-done_width)/2)
        if imgui.AnimButton('Done',imgui.ImVec2(done_width,40))then
            self.on_done(self.ids);self.open=false;imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
end
return S
