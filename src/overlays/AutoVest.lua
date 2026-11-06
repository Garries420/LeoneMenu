local C=require('src.components.AutoVest')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local function cooldown_seconds()
        local seconds=C:get_cooldown_remaining()
        if seconds==0 and Realign:is_preview('vesting') then return 3 end
        return seconds
    end
    local overlay=Overlay.new(cfg,function() return Realign:is_preview('vesting') or (cfg.display[0] and C:get_pending_offer()~=nil) end,function(self)
        local p=C:get_pending_offer()
        if not p and Realign:is_preview('vesting') then p={name='Preview_Player',id=21,price=200} end
        if not p then return end
        local id=p.id and tostring(p.id) or '?'
        self:TextRGB(string.format('{FFFFFF}%s Offered to: {5CCCE6}%s (%s) [$%d]',fa('SHIELD'),p.name:gsub('_',' '),id,p.price))
    end)
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('vest_to',overlay)

    local cooldown=Overlay.new(cfg,function()
        return (cfg.display[0] or Realign:is_preview('vesting')) and cooldown_seconds()>0
    end,function(self)
        local seconds=cooldown_seconds()
        if seconds>0 then self:TextRGB(('{FFFFFF}%s CD: {28DC40}%ds'):format(fa('CLOCK'),seconds)) end
    end)
    cooldown.prepare_layout=Layout.position_vest_cooldown
    cooldown.allowed_colors={['28DC40']=true}
    Layout.bind('vest_cooldown',cooldown)
end
return {create=create}
