-- Shared screen-space anchor; spacing remains four pixels at any resolution.
local L={}
function L.bind(kind,overlay) L[kind]=overlay end
local function horizontal(cfg)return cfg.horizontal and cfg.horizontal[0]end
local function scale(cfg)return cfg.scale and cfg.scale[0] or 1 end
local function sync(cfg,anchor)
    if cfg.scale and anchor.scale then cfg.scale[0]=anchor.scale[0] end
    if cfg.horizontal and anchor.horizontal then cfg.horizontal[0]=anchor.horizontal[0] end
end
local function extent(overlay,axis)
    if not overlay or not overlay.condition() then return 0 end
    local cfg=overlay.config
    local value
    if axis=='x' then value=overlay.last_width else value=overlay.last_height end
    if value then return value*scale(cfg)/(overlay.last_scale or scale(cfg))+4 end
    return ((axis=='x' and cfg.font_size[0]*18 or cfg.font_size[0]+2)+cfg.padding[0]*2)*scale(cfg)+4
end
function L.position_point()
    if not L.turf or not L.point then return end
    local imgui=require('upmimgui')
    local height=imgui.GetIO().DisplaySize.y
    if height<=0 then return end
    local anchor=L.turf.config
    local cfg=L.point.config
    sync(cfg,anchor)
    if horizontal(anchor) then
        cfg.pos.x[0]=anchor.pos.x[0];cfg.pos.y[0]=anchor.pos.y[0]
        return anchor.pos,0,extent(L.turf,'x')*(anchor.pos.x[0]>0.5 and -1 or 1)
    end
    local offset=0
    if L.turf.condition() then
        offset=extent(L.turf,'y')
    end
    cfg.pos.x[0]=anchor.pos.x[0]
    cfg.pos.y[0]=anchor.pos.y[0]+offset/height
end
local function row_spacing(overlay)
    return extent(overlay,'y')
end

function L.position_vest()
    if not L.vest_to then return end
    local anchor=L.vest_to.config
    if L.vest_by then sync(L.vest_by.config,anchor) end
    if horizontal(anchor) then return anchor.pos,0,extent(L.vest_to,'x')*(anchor.pos.x[0]>0.5 and -1 or 1) end
    return anchor.pos,row_spacing(L.vest_to)
end

function L.position_vest_cooldown()
    local cooldown=L.vest_cooldown
    local cfg=cooldown.config
    local anchor=cfg.pos
    if horizontal(cfg) then
        return anchor,0,(extent(L.vest_to,'x')+extent(L.vest_by,'x'))*(anchor.x[0]>0.5 and -1 or 1)
    end
    local height=require('upmimgui').GetIO().DisplaySize.y
    local gap=row_spacing(cooldown)
    local padding_delta=(cfg.padding[0]-(cfg.padding_anchor or cfg.padding[0]))*scale(cfg)
    if anchor.y[0]*height-padding_delta>=gap then return anchor,-gap end

    -- At the top edge, use the space beside the first offer.
    local offer=L.vest_to.condition() and L.vest_to or L.vest_by
    if not offer or not offer.condition() then return anchor,0 end
    local direction=anchor.x[0]>0.5 and -1 or 1
    return anchor,0,extent(offer,'x')*direction
end
return L
