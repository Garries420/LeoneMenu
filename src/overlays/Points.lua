-- Appearance change only: Sputnik's minute values and render-time refresh are retained.
local C=require('src.components.Points')
local Overlay=require('src.ui.Overlay')
local fa=require('fAwesome7')
local Layout=require('src.ui.CaptureLayout')
local Realign=require('src.utils.ElementRealigner')
local function create()
    local cfg=C:get_overlay_config()
    local active=C:get_active_point()
    local function visible()return ((not active.refresh_timer:is_paused() and cfg.display[0]) or (cfg.display_next_information[0] and C:get_next_point()~=nil)) end
    local overlay=Overlay.new(cfg,function()return Realign:is_preview('capture') or visible() end,function(self)
        if Realign:is_preview('capture') and not visible()then
            self:TextRGB(string.format('{FFFFFF}%s Point Capper: {5CCCE6}Preview Family {FFFFFF}| Estimated Time Left: {5CCCE6}1 minute',fa('SHIELD')))
            return
        end
        if not active.refresh_timer:is_paused() and cfg.display[0] then
            if active.refresh_timer:is_ready() then
                active.refresh_timer:trigger()
                samp_send_hidden_command('pointinfo')
            end
            local minutes=active.time_left
            local unit=minutes==1 and 'minute' or 'minutes'
            self:TextRGB(string.format('{FFFFFF}%s Point Capper: {5CCCE6}%s {FFFFFF}| Estimated Time Left: {5CCCE6}%d %s',fa('SHIELD'),require('src.core.Rules').strip(active.captured_by),minutes,unit))
        elseif cfg.display_next_information[0] then
            local name=C:get_next_point()
            local data=name and C:get_point_data(name)
            if data then self:TextRGB(string.format('{FFFFFF}%s %s | {5CCCE6}%s {FFFFFF}| %s {5CCCE6}%d hours',fa('LOCATION_DOT'),name,require('src.core.Rules').strip(data.owner),fa('CLOCK'),data.hours)) end
        end
    end)
    overlay.prepare_layout=Layout.position_point
    overlay.allowed_colors={['5CCCE6']=true}
    Layout.bind('point',overlay)
end
return {create=create}
