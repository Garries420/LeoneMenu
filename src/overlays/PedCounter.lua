-- Module: F:\2025\EDrive\dev\luapack\src\overlays\PedCounter.lua

local Overlay = require("src.ui.Overlay")
local PedCounter = require("src.components.PedCounter")

local function create()
    local cfg = PedCounter:get_overlay_config()

    Overlay.new(
        cfg,
        function()
            if not cfg.display[0] then
                return false
            end

            if not cfg.display_outside_interiors[0] and getActiveInterior() == 0 then
                return false
            end

            return true
        end,
        function(self)
            self:TextRGB("{1E3348}PEDS: {FFFFFF}" .. PedCounter:get_active_slots())
        end
    )
end

return {
    create = create
}
