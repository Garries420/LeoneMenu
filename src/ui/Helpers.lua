local imgui=require('upmimgui')
local shared=require('src.shared')
local H={color=imgui.ImVec4(30/255,51/255,72/255,1)}
H.position_label='Change overlay position - Left mouse click to save | ESC to cancel | Scroll wheel up and down to change size'
function H.position_tip()
    if imgui.IsItemHovered() then
        imgui.SetTooltip('%s','Mouse button 1: save position and size\nESC: cancel changes\nScroll wheel up/down: change size in 2% steps')
    end
end
function H.position_text(width,button_width)
    imgui.BeginGroup()
    imgui.PushTextWrapPos(math.max(40,width-button_width-12))
    imgui.TextWrapped(H.position_label)
    imgui.PopTextWrapPos()
    imgui.EndGroup()
    imgui.SameLine(width-button_width)
end
function H.realign(configs,prefix)
    local saved={}
    for i,cfg in ipairs(configs) do
        cfg.scale=cfg.scale or imgui.new.float(1)
        saved[i]={x=cfg.pos.x[0],y=cfg.pos.y[0],scale=cfg.scale[0]}
    end
    require('src.utils.ElementRealigner'):realign_element(function(x,y)
        for _,cfg in ipairs(configs) do cfg.pos.x[0]=x;cfg.pos.y[0]=y end
    end,{
        preview=prefix,
        on_resize=function(steps)
            local scale=math.floor(math.max(0.5,math.min(2,configs[1].scale[0]+steps*0.02))*100+0.5)/100
            for _,cfg in ipairs(configs)do cfg.scale[0]=scale end
        end,
        on_cancel=function()
            for i,cfg in ipairs(configs)do
                cfg.pos.x[0]=saved[i].x;cfg.pos.y[0]=saved[i].y;cfg.scale[0]=saved[i].scale
            end
        end,
    })
end
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
        H.position_text(width,200+imgui.GetStyle().ItemSpacing.x)
        if imgui.AnimButton('Style##'..prefix,imgui.ImVec2(80,0)) then
            local horizontal=not configs[1].horizontal[0]
            for _,cfg in ipairs(configs)do cfg.horizontal[0]=horizontal end
            save_config()
        end
        if imgui.IsItemHovered()then imgui.SetTooltip('Changes the style of the overlay. Stacked and Vertical')end
        imgui.SameLine()
        if imgui.AnimButton('Position##'..prefix,imgui.ImVec2(120,0)) then
            H.realign(configs,prefix)
        end
        H.position_tip()
    end)
end
H.open=require('src.utils.Browser')
function H.input(label,value,hint,width,len)
    return imgui.StyledInputText(label,value,hint,imgui.ImVec2(width or 250,0),len or 256)
end
return H
