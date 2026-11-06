local C=require('src.components.AcceptVest')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('vesting') or (cfg.display[0] and C:get_pending_offer()~=nil) end,function(self)
        local p=C:get_pending_offer()
        if not p and Realign:is_preview('vesting') then p={name='Preview_Player',id=42,price=200} end
        if not p then return end
        local id=p.id and tostring(p.id) or '?'
        self:TextRGB(string.format('{FFFFFF}%s Offered by: {5CCCE6}%s (%s) [$%d]',fa('SHIELD'),p.name:gsub('_',' '),id,p.price))
    end)
    overlay.prepare_layout=Layout.position_vest
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('vest_by',overlay)
end
return {create=create}
