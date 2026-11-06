-- Shared screen-space anchor; spacing remains four pixels at any resolution.
local L={}
function L.bind(kind,overlay) L[kind]=overlay end
function L.position_point()
    if not L.turf or not L.point then return end
    local imgui=require('upmimgui')
    local height=imgui.GetIO().DisplaySize.y
    if height<=0 then return end
    local anchor=L.turf.config
    local cfg=L.point.config
    local offset=0
    if L.turf.condition() then
        offset=(L.turf.last_height or (anchor.font_size[0]+anchor.padding[0]*2+2))+4
    end
    cfg.pos.x[0]=anchor.pos.x[0]
    cfg.pos.y[0]=anchor.pos.y[0]+offset/height
end
local function row_spacing(overlay)
    if not overlay or not overlay.condition() then return 0 end
    local cfg=overlay.config
    return (overlay.last_height or (cfg.font_size[0]+cfg.padding[0]*2+2))+4
end

function L.position_vest()
    if L.vest_to then return L.vest_to.config.pos,row_spacing(L.vest_to) end
end

function L.position_vest_cooldown()
    local cooldown=L.vest_cooldown
    local cfg=cooldown.config
    local anchor=cfg.pos
    local height=require('upmimgui').GetIO().DisplaySize.y
    local gap=row_spacing(cooldown)
    local padding_delta=cfg.padding[0]-(cfg.padding_anchor or cfg.padding[0])
    if anchor.y[0]*height-padding_delta>=gap then return anchor,-gap end

    -- At the top edge, use the space beside the first offer.
    local offer=L.vest_to.condition() and L.vest_to or L.vest_by
    if not offer or not offer.condition() then return anchor,0 end
    local width=offer.last_width or (cfg.font_size[0]*18+cfg.padding[0]*2)
    local direction=anchor.x[0]>0.5 and -1 or 1
    return anchor,0,(width+4)*direction
end
return L
