-- Appearance change only: Sputnik's minute values and render-time refresh are retained.
local C=require('src.components.Turfs')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local Rules=require('src.core.Rules')
local function create()
    local cfg=C:get_overlay_config()
    local active=C:get_active_turf()
    local function visible()return (not active.refresh_timer:is_paused() and cfg.display_war_information[0]) or (cfg.display_next_information[0] and C:get_next_turf()~=nil) end
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('capture') or visible() end,function(self)
        if Realign:is_preview('capture') and not visible()then
            self:TextRGB(string.format('{FFFFFF}%s Turf Capper: {5CCCE6}Preview Family (Pershing Sq.) {FFFFFF}| Time Left: {5CCCE6}7 minutes',fa('SHIELD')))
            return
        end
        if not active.refresh_timer:is_paused() and cfg.display_war_information[0] then
            if active.refresh_timer:is_ready() then
                active.refresh_timer:trigger()
                samp_send_hidden_command('turfinfo')
            end
            local minutes=active.time_left
            local unit=minutes==1 and 'minute' or 'minutes'
            local name=Rules.short_turf(active.name)
            local location=name~='' and (' ('..name..')') or ''
            self:TextRGB(string.format('{FFFFFF}%s Turf Capper: {5CCCE6}%s%s {FFFFFF}| Time Left: {5CCCE6}%d %s',fa('SHIELD'),Rules.strip(active.captured_by),location,minutes,unit))
        elseif cfg.display_next_information[0] then
            local name=C:get_next_turf()
            local data=name and C:get_turf_data(name)
            if data then self:TextRGB(string.format('{FFFFFF}%s %s | {5CCCE6}%s {FFFFFF}| %s {5CCCE6}%d hours',fa('LOCATION_DOT'),name,require('src.core.Rules').strip(data.owner),fa('CLOCK'),data.hours)) end
        end
    end)
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('turf',overlay)
end
return {create=create}
