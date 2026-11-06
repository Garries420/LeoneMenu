local imgui=require('upmimgui')
local shared=require('src.shared')
local H={color=imgui.ImVec4(30/255,51/255,72/255,1)}
function H.toggle(label,id,value,width,tip)
    imgui.Text(label)
    if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip) end
    imgui.SameLine(width-imgui.ToggleButtonWidth())
    return imgui.ToggleButton('##'..id,value)
end
function H.bind(label,id,cfg,width)
    imgui.Text(label);imgui.SameLine(width-180)
    local keys=shared.hotkey_manager:draw_key_editor(id,imgui.ImVec2(180,0))
    if keys then cfg.keys=keys end
end
function H.position(configs,prefix)
    imgui.DrawChild('Position##'..prefix,function(width)
        imgui.Text('Overlay position on screen');imgui.SameLine(width-120)
        if imgui.AnimButton('Position##'..prefix,imgui.ImVec2(120,0)) then
            require('src.utils.ElementRealigner'):realign_element(function(x,y)
                for i,c in ipairs(configs) do c.pos.x[0]=x;c.pos.y[0]=math.min(0.97,y+(i-1)*0.035) end
            end,{preview=prefix})
        end
    end)
end
H.open=require('src.utils.Browser')
function H.input(label,value,hint,width,len)
    return imgui.StyledInputText(label,value,hint,imgui.ImVec2(width or 250,0),len or 256)
end
return H
